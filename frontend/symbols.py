"""Lexical binding identities for py2v's AST frontend (Python 3.9+).

This module never executes, compiles, or imports the source being analyzed.
Analysis adds private attributes to existing AST nodes; it does not replace them.

Source spellings of class-private names (``__name``) are deliberately preserved.
CPython mangles them for bytecode; the verifier translates names *only* when
comparing with CPython's symbol table.
"""

from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass, field
import json
import symtable
import sys
import tokenize
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple


Site = Tuple[int, int, str]
_SCOPE_KINDS = ("module", "function", "lambda", "class", "comprehension", "type_params")
_BIND_KINDS = ("local", "param", "module_global", "class_attr", "import", "function", "class")
_HOW = ("assign", "augassign", "annassign", "ann_only", "for", "with", "except",
        "import", "def", "class", "param", "walrus", "match", "del", "comp_for", "type_param")


@dataclass
class Scope:
    id: int
    kind: str
    name: str
    parent: Optional[int]
    lineno: int
    col_offset: int
    has_star_import: bool = False
    _role: str = field(default="", repr=False)
    _children: List[int] = field(default_factory=list, repr=False)
    _global: Set[str] = field(default_factory=set, repr=False)
    _nonlocal: Set[str] = field(default_factory=set, repr=False)
    _locals: Set[str] = field(default_factory=set, repr=False)
    _private_class: str = field(default="", repr=False)
    _node: Optional[ast.AST] = field(default=None, repr=False)
    _can_see_class: bool = field(default=False, repr=False)

    def to_json(self) -> Dict[str, Any]:
        return {"id": self.id, "kind": self.kind, "name": self.name,
                "parent": self.parent, "lineno": self.lineno,
                "col_offset": self.col_offset, "has_star_import": self.has_star_import}


@dataclass
class Binding:
    id: int
    scope: int
    name: str
    kind: str
    sites: List[Site] = field(default_factory=list)
    is_param: bool = False
    rebound: bool = False
    captured: bool = False
    declared_global: bool = False
    declared_nonlocal: bool = False

    def to_json(self) -> Dict[str, Any]:
        return {"id": self.id, "scope": self.scope, "name": self.name,
                "kind": self.kind, "sites": [list(s) for s in self.sites],
                "is_param": self.is_param, "rebound": self.rebound,
                "captured": self.captured, "declared_global": self.declared_global,
                "declared_nonlocal": self.declared_nonlocal}


@dataclass
class SymbolTable:
    scopes: List[Scope]
    bindings: List[Binding]
    _occurrences: List["_Occurrence"] = field(default_factory=list, repr=False)
    _by_owner: Dict[Tuple[int, str], Binding] = field(default_factory=dict, repr=False)
    _future_annotations: bool = field(default=False, repr=False)

    def to_json(self) -> Dict[str, Any]:
        return {"scopes": [s.to_json() for s in self.scopes],
                "bindings": [b.to_json() for b in self.bindings]}

    def binding(self, scope_id: int, name: str) -> Optional[Binding]:
        """Return a binding owned by this scope, if any."""
        return self._by_owner.get((scope_id, name))


@dataclass
class _Occurrence:
    node: ast.AST
    scope: int
    name: str
    role: str                  # load, site, global, nonlocal, star
    how: str = ""
    bind_kind: str = ""
    owner_override: Optional[int] = None
    active: bool = True        # false for postponed/unevaluated annotations
    order: int = 0
    lineno: int = 0
    col_offset: int = 0


def _location(node: ast.AST) -> Tuple[int, int]:
    return (int(getattr(node, "lineno", 0)), int(getattr(node, "col_offset", 0)))


def _is(node: ast.AST, type_name: str) -> bool:
    cls = getattr(ast, type_name, None)
    return cls is not None and isinstance(node, cls)


class _Collector(ast.NodeVisitor):
    def __init__(self, tree: ast.Module) -> None:
        root = Scope(0, "module", "top", None, 0, 0, _role="module", _node=tree)
        self.table = SymbolTable([root], [])
        self.current = 0
        self.annotation_active = True
        self._next_order = 0
        self._annotation_groups: Dict[int, int] = {}
        self.table._future_annotations = any(
            isinstance(s, ast.ImportFrom) and s.module == "__future__"
            and any(a.name == "annotations" for a in s.names)
            for s in tree.body
        )
        setattr(tree, "_scope_id", 0)

    def _new(self, node: ast.AST, kind: str, name: str, role: str,
             location_node: Optional[ast.AST] = None,
             scope_attribute: Optional[str] = None) -> int:
        parent = self.current
        line, col = _location(location_node if location_node is not None else node)
        previous = self.table.scopes[parent]._private_class
        if (kind == "class" or
                (kind == "type_params" and role == "type parameters" and
                 isinstance(node, ast.ClassDef))):
            previous = name.lstrip("_")
        sid = len(self.table.scopes)
        p = self.table.scopes[parent]
        sees_class = ((kind == "type_params" and
                       (p.kind == "class" or p._can_see_class)) or
                      (kind == "comprehension" and p._can_see_class))
        if (kind == "type_params" and role == "annotation" and
                isinstance(node, ast.AnnAssign) and
                self.table._future_annotations):
            # 3.14+: a class variable's future-string annotation does
            # not receive LOAD_FROM_DICT_OR_GLOBALS class visibility.
            sees_class = False
        scope = Scope(sid, kind, name, parent, line, col,
                      _role=role, _private_class=previous, _node=node,
                      _can_see_class=sees_class)
        self.table.scopes.append(scope)
        self.table.scopes[parent]._children.append(sid)
        if scope_attribute is not None:
            setattr(node, scope_attribute, sid)
        elif kind == "type_params" and role == "type parameters":
            # A generic def/class node also opens its ordinary body scope.
            setattr(node, "_type_params_scope_id", sid)
        elif kind == "type_params" and role == "annotation" and isinstance(
                node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            setattr(node, "_annotation_scope_id", sid)
        else:
            setattr(node, "_scope_id", sid)
        return sid

    def _enter(self, sid: int, nodes: Iterable[ast.AST]) -> None:
        was = self.current
        self.current = sid
        try:
            for node in nodes:
                self.visit(node)
        finally:
            self.current = was

    def _event(self, node: ast.AST, name: str, role: str,
               how: str = "", kind: str = "", override: Optional[int] = None) -> None:
        line, col = _location(node)
        self.table._occurrences.append(_Occurrence(
            node, self.current, name, role, how, kind, override,
            self.annotation_active, self._next_order, line, col))
        self._next_order += 1

    def _load_annotation(self, node: Optional[ast.AST],
                         origin: Optional[ast.AST] = None) -> None:
        if node is None:
            return
        before = self.annotation_active
        modern = sys.version_info >= (3, 14)
        parent = self.table.scopes[self.current]
        # Before PEP 649, future annotations do not contribute symbol uses.
        # In 3.14+, CPython creates a separate __annotate__ symtable even
        # with the future import; its identifiers remain visible there.
        if not modern and self.table._future_annotations:
            self.annotation_active = False
        try:
            if modern and origin is not None:
                # Each module/class/function shares a single annotation table
                # for its variable annotations. Function-local annotations
                # are *not evaluated*: CPython records no name uses inside
                # their __annotate__ table (symtable.c: ste_in_unevaluated_annotation).
                sid = self._annotation_groups.get(self.current)
                if sid is None:
                    sid = self._new(origin, "type_params", "__annotate__", "annotation",
                                    location_node=node,
                                    scope_attribute="_annotation_scope_id")
                    self._annotation_groups[self.current] = sid
                if parent.kind in ("function", "lambda"):
                    self.annotation_active = False
                self._enter(sid, [node])
            else:
                self.visit(node)
        finally:
            self.annotation_active = before

    def _target(self, node: ast.AST, how: str,
                override: Optional[int] = None) -> None:
        if isinstance(node, ast.Name):
            self._event(node, node.id, "site", how, override=override)
        elif isinstance(node, (ast.Tuple, ast.List)):
            for part in node.elts:
                self._target(part, how, override)
        elif isinstance(node, ast.Starred):
            self._target(node.value, how, override)
        else:
            # Assignment to obj.attr or obj[index] reads obj/index, not a
            # binding for obj. Name nodes in these subtrees normally have Load.
            self.visit(node)

    def visit_Name(self, node: ast.Name) -> None:
        if isinstance(node.ctx, ast.Load):
            self._event(node, node.id, "load")
            if node.id == "super" and self.table.scopes[self.current].kind in (
                    "function", "lambda", "comprehension"):
                # CPython injects a hidden __class__ reference for *any*
                # super name load in a function, even plain `return super`.
                # A detached synthetic Name preserves the input tree shape.
                implicit = ast.copy_location(ast.Name(id="__class__", ctx=ast.Load()), node)
                self._event(implicit, "__class__", "load")
        elif isinstance(node.ctx, ast.Del):
            self._event(node, node.id, "site", "del")
        else:
            self._event(node, node.id, "site", "assign")

    def visit_Global(self, node: ast.Global) -> None:
        self.table.scopes[self.current]._global.update(node.names)
        for name in node.names:
            self._event(node, name, "global")

    def visit_Nonlocal(self, node: ast.Nonlocal) -> None:
        self.table.scopes[self.current]._nonlocal.update(node.names)
        for name in node.names:
            self._event(node, name, "nonlocal")

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            name = alias.asname or alias.name.split(".", 1)[0]
            self._event(alias, name, "site", "import", "import")

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        for alias in node.names:
            if alias.name == "*":
                self.table.scopes[self.current].has_star_import = True
                self._event(alias, "*", "star")
            else:
                self._event(alias, alias.asname or alias.name,
                            "site", "import", "import")

    def visit_Assign(self, node: ast.Assign) -> None:
        self.visit(node.value)
        for target in node.targets:
            self._target(target, "assign")
        # The target of a TypeComment is textual and does not create a scope.

    def visit_NamedExpr(self, node: ast.NamedExpr) -> None:
        self.visit(node.value)
        sid = self.current
        if self.table.scopes[sid].kind == "comprehension":
            # PEP 572: skip *all* surrounding comprehensions and class blocks.
            # A class-body comprehension with := is invalid Python; retaining
            # a nearest-function-or-module owner gives an identity for an AST
            # obtained without CPython's later semantic validation.
            while self.table.scopes[sid].kind not in ("function", "lambda", "module"):
                parent = self.table.scopes[sid].parent
                if parent is None:
                    break
                sid = parent
        self._target(node.target, "walrus", sid)

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        self._target(node.target, "augassign")
        self.visit(node.value)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        if node.value is not None:
            self.visit(node.value)
        self._target(node.target, "annassign" if node.value is not None else "ann_only")
        self._load_annotation(node.annotation, node)

    def visit_Delete(self, node: ast.Delete) -> None:
        for target in node.targets:
            self._target(target, "del")

    def visit_For(self, node: ast.For) -> None:
        self.visit(node.iter)
        self._target(node.target, "for")
        for child in node.body:
            self.visit(child)
        for child in node.orelse:
            self.visit(child)

    visit_AsyncFor = visit_For

    def visit_With(self, node: ast.With) -> None:
        for item in node.items:
            self.visit(item.context_expr)
            if item.optional_vars is not None:
                self._target(item.optional_vars, "with")
        for child in node.body:
            self.visit(child)

    visit_AsyncWith = visit_With

    def visit_ExceptHandler(self, node: ast.ExceptHandler) -> None:
        if node.type is not None:
            self.visit(node.type)
        if node.name is not None:
            self._event(node, node.name, "site", "except")
        for child in node.body:
            self.visit(child)
        # Compiler-generated deletion after the suite is intentional, not
        # a second explicit source-level binding site.

    def visit_MatchAs(self, node: ast.AST) -> None:
        pat = getattr(node, "pattern", None)
        if pat is not None:
            self.visit(pat)
        name = getattr(node, "name", None)
        if name is not None:
            self._event(node, name, "site", "match")

    def visit_MatchStar(self, node: ast.AST) -> None:
        name = getattr(node, "name", None)
        if name is not None:
            self._event(node, name, "site", "match")

    def visit_MatchMapping(self, node: ast.AST) -> None:
        for expr in getattr(node, "keys", []):
            self.visit(expr)
        for pat in getattr(node, "patterns", []):
            self.visit(pat)
        rest = getattr(node, "rest", None)
        if rest is not None:
            self._event(node, rest, "site", "match")

    def _defaults(self, arguments: ast.arguments) -> None:
        for value in arguments.defaults:
            self.visit(value)
        for value in arguments.kw_defaults:
            if value is not None:
                self.visit(value)

    def _annotations(self, arguments: ast.arguments) -> None:
        for a in (list(arguments.posonlyargs) + list(arguments.args)
                  + ([arguments.vararg] if arguments.vararg is not None else [])
                  + list(arguments.kwonlyargs)
                  + ([arguments.kwarg] if arguments.kwarg is not None else [])):
            self._load_annotation(a.annotation)

    def _parameters(self, arguments: ast.arguments) -> None:
        for arg in (list(arguments.posonlyargs) + list(arguments.args)
                    + ([arguments.vararg] if arguments.vararg is not None else [])
                    + list(arguments.kwonlyargs)
                    + ([arguments.kwarg] if arguments.kwarg is not None else [])):
            self._event(arg, arg.arg, "site", "param", "param")

    def _type_parameters(self, node: ast.AST, name: str) -> Optional[int]:
        parameters = getattr(node, "type_params", None)
        if not parameters:
            return None
        tp = self._new(node, "type_params", name, "type parameters")
        was = self.current
        self.current = tp
        try:
            for item in parameters:
                pname = getattr(item, "name", None)
                if isinstance(pname, str):
                    self._event(item, pname, "site", "type_param", "local")
                bound = getattr(item, "bound", None)
                default = getattr(item, "default_value", None)
                # Since PEP 696, a type variable's bound and default have
                # distinct CPython symbol tables, even for the same TypeVar.
                # The first uses the historical _scope_id on the TypeVar;
                # the second uses an additional private attribute.
                if bound is not None:
                    sub = self._new(item, "type_params", pname or "?", "type variable",
                                    location_node=bound)
                    self._enter(sub, [bound])
                if default is not None:
                    sub = self._new(item, "type_params", pname or "?", "type variable",
                                    location_node=default,
                                    scope_attribute=("_type_param_default_scope_id"
                                                     if bound is not None else None))
                    self._enter(sub, [default])
        finally:
            self.current = was
        return tp

    def _function(self, node: ast.AST, is_async: bool = False) -> None:
        del is_async
        name = getattr(node, "name")
        self._event(node, name, "site", "def", "function")
        for expr in node.decorator_list:
            self.visit(expr)
        # CPython visits/evaluates ordinary default arguments *before*
        # entering a generic function's type-parameter scope.
        self._defaults(node.args)
        tp = self._type_parameters(node, name)
        before = self.current
        if tp is not None:
            self.current = tp
        try:
            if sys.version_info >= (3, 14):
                # PEP 649/749: an independent lazily evaluated annotation
                # block; in CPython symtable it is a sibling of the body
                # function, even when it contains no annotation names.
                ann = self._new(node, "type_params", "__annotate__", "annotation")
                self.current = ann
                self._annotations(node.args)
                self._load_annotation(node.returns)
                self.current = tp if tp is not None else before
            else:
                self._annotations(node.args)
                self._load_annotation(node.returns)
            child = self._new(node, "function", name, "function")
        finally:
            self.current = before
        self.current = child
        try:
            self._parameters(node.args)
            for stmt in node.body:
                self.visit(stmt)
        finally:
            self.current = before

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._function(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._function(node, True)

    def visit_Lambda(self, node: ast.Lambda) -> None:
        self._defaults(node.args)
        child = self._new(node, "lambda", "lambda", "function")
        was = self.current
        self.current = child
        try:
            self._parameters(node.args)
            self.visit(node.body)
        finally:
            self.current = was

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        self._event(node, node.name, "site", "class", "class")
        for expr in node.decorator_list:
            self.visit(expr)
        tp = self._type_parameters(node, node.name)
        before = self.current
        if tp is not None:
            self.current = tp
        try:
            for base in node.bases:
                self.visit(base)
            for kw in node.keywords:
                self.visit(kw.value)
            child = self._new(node, "class", node.name, "class")
        finally:
            self.current = before
        self._enter(child, node.body)

    def visit_TypeAlias(self, node: ast.AST) -> None:
        # PEP 695 type aliases have a *lazy* RHS, even without parameters.
        name_node = getattr(node, "name")
        if isinstance(name_node, ast.Name):
            self._event(name_node, name_node.id, "site", "assign")
            name = name_node.id
        else:
            name = "<type alias>"
        tp = self._type_parameters(node, name)
        was = self.current
        if tp is not None:
            self.current = tp
        try:
            alias_scope = self._new(node, "type_params", name, "type alias")
        finally:
            self.current = was
        self._enter(alias_scope, [getattr(node, "value")])

    def _comprehension(self, node: ast.AST, name: str) -> None:
        generators = getattr(node, "generators")
        # First iterable is evaluated OUTSIDE the implicit comprehension scope.
        self.visit(generators[0].iter)
        child = self._new(node, "comprehension", name, "function")
        was = self.current
        self.current = child
        try:
            for index, gen in enumerate(generators):
                if index:
                    self.visit(gen.iter)
                self._target(gen.target, "comp_for")
                for condition in gen.ifs:
                    self.visit(condition)
            if isinstance(node, ast.DictComp):
                self.visit(node.key)
                if node.value is not None:  # `{**d for d in ds}` (3.15) has no value
                    self.visit(node.value)
            else:
                self.visit(node.elt)
        finally:
            self.current = was

    def visit_ListComp(self, node: ast.ListComp) -> None:
        self._comprehension(node, "listcomp")

    def visit_SetComp(self, node: ast.SetComp) -> None:
        self._comprehension(node, "setcomp")

    def visit_DictComp(self, node: ast.DictComp) -> None:
        self._comprehension(node, "dictcomp")

    def visit_GeneratorExp(self, node: ast.GeneratorExp) -> None:
        self._comprehension(node, "genexpr")


class _Resolver:
    def __init__(self, collected: SymbolTable) -> None:
        self.t = collected
        self.scopes = collected.scopes
        self.occ = collected._occurrences
        self._site_owner: Dict[int, int] = {}

    def _enclosing_nonlocal(self, sid: int, name: str) -> Optional[int]:
        parent = self.scopes[sid].parent
        while parent is not None:
            p = self.scopes[parent]
            if p.kind in ("function", "lambda") and name in p._locals:
                return parent
            parent = p.parent
        return None

    def _effective_owner(self, occ: _Occurrence) -> int:
        if occ.owner_override is not None:
            start = occ.owner_override
        else:
            start = occ.scope
        s = self.scopes[start]
        if occ.name in s._global:
            return 0
        if occ.name in s._nonlocal:
            parent = self._enclosing_nonlocal(start, occ.name)
            if parent is not None:
                return parent
        return start

    def _kind(self, owner: int, occ: _Occurrence) -> str:
        if occ.bind_kind and occ.bind_kind != "local":
            return occ.bind_kind
        s = self.scopes[owner]
        if s.kind == "module":
            return "module_global"
        if s.kind == "class":
            return "class_attr"
        return "local"

    def _make_binding(self, sid: int, name: str, kind: str) -> Binding:
        key = sid, name
        existing = self.t._by_owner.get(key)
        if existing is not None:
            return existing
        result = Binding(len(self.t.bindings), sid, name, kind)
        self.t.bindings.append(result)
        self.t._by_owner[key] = result
        return result

    def _prepare(self) -> None:
        # Build local sets *after* seeing global/nonlocal declarations, which
        # apply throughout the entire containing code block.
        for o in self.occ:
            if o.role == "site":
                start = o.owner_override if o.owner_override is not None else o.scope
                if (o.name not in self.scopes[start]._global and
                        o.name not in self.scopes[start]._nonlocal):
                    self.scopes[start]._locals.add(o.name)
        events = sorted((o for o in self.occ if o.role == "site"),
                        key=lambda o: (o.lineno, o.col_offset, o.order))
        for o in events:
            owner = self._effective_owner(o)
            b = self._make_binding(owner, o.name, self._kind(owner, o))
            b.sites.append((o.lineno, o.col_offset, o.how))
            b.is_param = b.is_param or o.how == "param"
        for b in self.t.bindings:
            b.rebound = len(b.sites) > 1 or any(
                how in ("augassign", "for", "del") for _, _, how in b.sites)
        # Explicit global statements reference a module binding even where
        # the module has no assignment. Such bindings have zero sites.
        for o in sorted((o for o in self.occ if o.role == "global"),
                        key=lambda o: (o.lineno, o.col_offset, o.order)):
            b = self._make_binding(0, o.name, "module_global")
            b.declared_global = True
        for o in self.occ:
            if o.role == "nonlocal":
                owner = self._enclosing_nonlocal(o.scope, o.name)
                if owner is not None:
                    b = self.t._by_owner.get((owner, o.name))
                    if b is not None:
                        b.declared_nonlocal = True
        for s in self.scopes:
            for name in s._global:
                b = self.t._by_owner.get((0, name))
                if b is not None:
                    b.declared_global = True

    def _resolve(self, sid: int, name: str, declaration: str = "") -> Tuple[Optional[Binding], str]:
        s = self.scopes[sid]
        if declaration == "global" or name in s._global:
            return self.t._by_owner.get((0, name)), "global"
        if declaration == "nonlocal" or name in s._nonlocal:
            owner = self._enclosing_nonlocal(sid, name)
            return (self.t._by_owner.get((owner, name)) if owner is not None else None,
                    "enclosing")
        direct = self.t._by_owner.get((sid, name))
        if direct is not None:
            return direct, "global" if sid == 0 else "local"
        # Class namespace lookup is special: it may read itself, but methods
        # and nested scopes must NOT close over ordinary class attributes.
        parent = s.parent
        while parent is not None:
            p = self.scopes[parent]
            if p.kind == "class":
                if name == "__class__" and s.kind in ("function", "lambda", "comprehension"):
                    return self._make_binding(parent, "__class__", "class_attr"), "enclosing"
                if s.kind == "type_params" and s._can_see_class:
                    # PEP 695/649 annotation blocks can read the class dict
                    # dynamically; match a known class attribute as a static
                    # candidate, without treating it as a closure cell.
                    b = self.t._by_owner.get((parent, name))
                    if b is not None:
                        return b, "enclosing"
                parent = p.parent
                continue
            if name in p._global:
                return self.t._by_owner.get((0, name)), "global"
            b = self.t._by_owner.get((parent, name))
            if b is not None:
                return b, "global" if parent == 0 else "enclosing"
            parent = p.parent
        return None, "builtin_or_unknown"

    @staticmethod
    def _attach(o: _Occurrence, binding: Optional[Binding], resolution: str) -> None:
        n = o.node
        if isinstance(n, (ast.Global, ast.Nonlocal)):
            for attr, value in (("_scope", o.scope),
                                ("_binding", binding.id if binding else None),
                                ("_resolution", resolution)):
                data = getattr(n, attr, None)
                if data is None:
                    data = {}
                    setattr(n, attr, data)
                data[o.name] = value
        else:
            setattr(n, "_scope", o.scope)
            setattr(n, "_binding", binding.id if binding else None)
            setattr(n, "_resolution", resolution)

    def run(self) -> SymbolTable:
        self._prepare()
        for o in self.occ:
            if o.role == "star":
                self._attach(o, None, "builtin_or_unknown")
            elif o.role == "global":
                b, resolution = self._resolve(o.scope, o.name, "global")
                self._attach(o, b, resolution)
            elif o.role == "nonlocal":
                b, resolution = self._resolve(o.scope, o.name, "nonlocal")
                self._attach(o, b, resolution)
            elif o.role == "site":
                owner = self._effective_owner(o)
                b = self.t._by_owner[(owner, o.name)]
                resolution = ("global" if owner == 0 else
                              "local" if owner == o.scope else "enclosing")
                if o.active and owner != o.scope and owner != 0 and (
                        self.scopes[owner].kind != "class" or b.name == "__class__"):
                    b.captured = True
                self._attach(o, b, resolution)
            else:
                b, resolution = self._resolve(o.scope, o.name)
                if o.active and b is not None and b.scope not in (0, o.scope) and (
                        self.scopes[b.scope].kind != "class" or b.name == "__class__"):
                    b.captured = True
                self._attach(o, b, resolution)
        return self.t


def analyze(tree: ast.Module) -> SymbolTable:
    """Build lexical binding identities on a parsed Python module, in place.

    No code object is created and the input AST remains structurally unchanged.
    Source order (line, column, stable traversal ordinal) decides binding IDs.
    A syntactically parsed but semantically illegal program is not validated.
    """
    if not isinstance(tree, ast.Module):
        raise TypeError("analyze() requires ast.Module")
    collector = _Collector(tree)
    collector.visit(tree)
    return _Resolver(collector.table).run()


# VERIFIER ------------------------------------------------------------------

def _mangle(name: str, classname: str) -> str:
    # CPython's private-name mangling is a *comparison-only* normalization.
    if classname and name.startswith("__") and not name.endswith("__") and "." not in name:
        return "_" + classname + name
    return name


def _sym_kind(st: Any) -> str:
    value = st.get_type()
    result = str(getattr(value, "value", value)).lower()
    # 3.12 used singular 'type parameter' and 'TypeVar bound'; 3.13+
    # renamed these categories in the public symtable API.
    return {"type parameter": "type parameters",
            "typevar bound": "type variable"}.get(result, result)


def _sym_key(st: Any) -> Tuple[str, str, int]:
    return _sym_kind(st), st.get_name(), st.get_lineno()


def _own_key(s: Scope) -> Tuple[str, str, int]:
    if s.kind == "module":
        return "module", "top", 0
    if s.kind == "class":
        return "class", s.name, s.lineno
    if s.kind in ("function", "lambda", "comprehension"):
        name = s.name
        # CPython 3.15 changed the anonymous scope spellings from lambda,
        # genexpr, etc. to <lambda>, <genexpr>, <listcomp>, ... .  Their
        # symtable *kind* remains "function" (not "lambda" or "comprehension").
        if sys.version_info >= (3, 15) and s.kind in ("lambda", "comprehension"):
            name = "<{}>".format(name)
        return "function", name, s.lineno
    return s._role, s.name, s.lineno


def _inline(s: Scope) -> bool:
    # 3.12+ inline list/set/dict comprehensions, except inside an annotation
    # scope with class visibility (InternalDocs/inlined_comprehensions.md).
    return (sys.version_info >= (3, 12) and s.kind == "comprehension"
            and s.name != "genexpr" and not _class_visible_annotation(s))


def _class_visible_annotation(s: Scope) -> bool:
    # In annotation scopes lexically inside a class, CPython deliberately
    # retains a separate comprehension scope rather than inlining it.
    return s._can_see_class


@dataclass
class _VerificationReport:
    errors: List[str] = field(default_factory=list)
    skipped: int = 0
    reasons: List[str] = field(default_factory=list)

    def skip(self, reason: str) -> None:
        self.skipped += 1
        self.reasons.append(reason)


def _pair_tables(table: SymbolTable, root: Any,
                 report: _VerificationReport) -> Dict[int, Any]:
    paired: Dict[int, Any] = {0: root}

    def descend(sid: int, st: Any) -> None:
        expected: List[int] = []

        def flatten(child: int) -> None:
            scope = table.scopes[child]
            if _inline(scope):
                # A PEP 709 comprehension is a distinct *resolver* scope, but
                # has no separately comparable CPython symbol table. Count
                # this explicitly; do not pretend it was verified.
                report.skip("inlined {} scope at {}".format(scope.name, scope.lineno))
                for sub in scope._children:
                    flatten(sub)
            else:
                expected.append(child)

        for child in table.scopes[sid]._children:
            flatten(child)
        available = list(st.get_children())
        used: Set[int] = set()
        # Symtable exposes no column offsets. Two same-named lambdas (or
        # comprehensions) on a line cannot be paired *uniquely*. Consume
        # both groups, but count each skipped scope instead of choosing an
        # arbitrary match or reporting a spurious missing second scope.
        keys = [_own_key(table.scopes[child]) for child in expected]
        ambiguous = {key for key in keys if keys.count(key) > 1 and
                     not all(table.scopes[child]._role == "type variable"
                             for child in expected if _own_key(table.scopes[child]) == key)}
        for key in ambiguous:
            used.update(i for i, candidate in enumerate(available)
                        if _sym_key(candidate) == key)
        for child in expected:
            scope = table.scopes[child]
            key = _own_key(scope)
            if key in ambiguous:
                report.skip("ambiguous {} {} @{} under {}".format(
                    scope.kind, scope.name, scope.lineno, table.scopes[sid].name))
                continue
            candidates = [i for i, candidate in enumerate(available)
                          if i not in used and _sym_key(candidate) == key]
            if not candidates:
                msg = "scope missing in symtable: {} {} @{} (parent {})".format(
                    scope.kind, scope.name, scope.lineno, table.scopes[sid].name)
                if scope._role == "annotation":
                    # Annotations are deliberately represented as logical
                    # scopes. CPython has varied the generated __annotate__
                    # tables, and cannot always expose an equivalent.
                    report.skip(msg)
                else:
                    report.errors.append(msg)
                continue
            if len(candidates) > 1 and scope._role != "type variable":
                # A same-kind/same-name/same-line duplicate is ambiguous
                # without a public get_col_offset(). Avoid arbitrary pairing.
                report.skip("ambiguous {} {} @{} under {}".format(
                    scope.kind, scope.name, scope.lineno, table.scopes[sid].name))
                used.update(candidates)
                continue
            i = candidates[0]
            used.add(i)
            paired[child] = available[i]
            descend(child, available[i])
        for i, child in enumerate(available):
            if i not in used:
                msg = "extra symtable scope: {} {} @{} (parent {})".format(
                    *_sym_key(child), table.scopes[sid].name)
                if _sym_kind(child) == "annotation":
                    report.skip(msg)
                else:
                    report.errors.append(msg)

    descend(0, root)
    return paired


def _verify_detailed(source: str, filename: str,
                     table: SymbolTable) -> _VerificationReport:
    """Full verifier, including counts of comparisons not performed."""
    report = _VerificationReport()
    try:
        root = symtable.symtable(source, filename, "exec")
    except (SyntaxError, ValueError) as exc:
        # ast.parse succeeds on some semantically rejected programs; CPython's
        # symbol-table construction performs additional legality checks. This
        # is a non-comparable *whole file*, not a resolver disagreement.
        report.skip("{}: symtable rejected input: {}".format(filename, exc))
        return report
    paired = _pair_tables(table, root, report)
    errors = report.errors
    scope_names: Dict[int, Set[str]] = {s.id: set() for s in table.scopes}
    for o in table._occurrences:
        if o.role != "star" and o.active:
            scope_names[o.scope].add(o.name)
    for b in table.bindings:
        if b.sites or b.declared_global:
            scope_names[b.scope].add(b.name)
    # In CPython, a free name used only in a distant descendant is entered
    # into every intervening lexical table, even without a Name AST there.
    for o in table._occurrences:
        if not o.active or o.role == "star":
            continue
        bid = getattr(o.node, "_binding", None)
        if isinstance(bid, dict):
            bid = bid.get(o.name)
        if not isinstance(bid, int):
            continue
        b = table.bindings[bid]
        if b.scope == 0 or b.scope == o.scope:
            continue
        # Class-visible PEP 695/649 annotation blocks use the class dict;
        # this is not a lexical closure and does not propagate free symbols.
        if table.scopes[b.scope].kind == "class" and b.name != "__class__":
            continue
        parent = table.scopes[o.scope].parent
        while parent is not None and parent != b.scope:
            p = table.scopes[parent]
            # A class with an attribute called x also reports it local even
            # when a method captures an outer function's x (is_free_class).
            if not (p.kind == "class" and table.binding(parent, o.name)):
                scope_names[parent].add(o.name)
            parent = p.parent
    ignore_synthetics = {".0", ".defaults", ".kwdefaults", ".type_params",
                         ".generic_base", "__type_params__", "__classdict__",
                         ".format", "__conditional_annotations__"}
    for sid, st in paired.items():
        s = table.scopes[sid]
        direct = scope_names[sid]
        names = {_mangle(name, s._private_class): name for name in direct}
        for source_name in sorted(direct):
            name = _mangle(source_name, s._private_class)
            if name not in st.get_identifiers():
                # Class __class__ closure is generated by CPython without a
                # corresponding class-local symbol; skip class owner only.
                if s.kind == "class" and source_name == "__class__":
                    continue
                errors.append("{}:{} {} {}: absent from symtable".format(
                    filename, s.lineno, s.kind, source_name))
                continue
            theirs = st.lookup(name)
            own_sites = [o for o in table._occurrences if o.role == "site"
                         and o.name == source_name and
                         (o.owner_override == sid or
                          (o.scope == sid and o.owner_override is None))]
            is_own = (bool(own_sites) and source_name not in s._global and
                      source_name not in s._nonlocal)
            # A walrus in a module-level comprehension writes a module
            # variable, but CPython symtable considers it a declared global,
            # not a module-local DEF_LOCAL site, unless the module assigns it
            # separately. This differs from a walrus within a function.
            module_local_sites = any(o.scope == 0 for o in own_sites)
            if sid == 0:
                is_own = module_local_sites
            local_import = any(o.how == "import" for o in own_sites)
            declarations = source_name in s._global, source_name in s._nonlocal
            if declarations[0]:
                ours = (sid == 0 and module_local_sites, True, False, False, local_import)
            elif declarations[1]:
                ours = (False, False, True, False, False)
            elif is_own:
                ours = (True, sid == 0, False, any(o.how == "param" for o in own_sites),
                        local_import)
            else:
                lookup_occ = [o for o in table._occurrences
                              if o.scope == sid and o.name == source_name and o.active]
                if lookup_occ:
                    o = lookup_occ[0]
                    resolution = (getattr(o.node, "_resolution", {}) or {})
                    if isinstance(resolution, dict):
                        resolution = resolution.get(source_name)
                    binding_id = getattr(o.node, "_binding", None)
                    if isinstance(binding_id, dict):
                        binding_id = binding_id.get(source_name)
                    class_dict_name = (s.kind == "type_params" and
                                       s._can_see_class and
                                       isinstance(binding_id, int) and
                                       table.scopes[table.bindings[binding_id].scope].kind == "class")
                    # CPython class-visible annotation blocks classify a
                    # LOAD_FROM_DICT_OR_GLOBALS candidate as 'global', even
                    # when our source-level identity points at a class attr.
                    ours = (False, class_dict_name or resolution == "global" or
                            resolution == "builtin_or_unknown",
                            resolution == "enclosing" and not class_dict_name,
                            False, False)
                else:
                    # Implicit propagated free from a nested child, or an
                    # explicit global declaration in a descendant.
                    ours = (False, sid == 0, sid != 0, False, False)
            # CPython <=3.13 Symbol.is_global() mistakes a non-module
            # scope literally named "top" for the module (Lib/symtable.py
            # checks the name, not its block type). Correct this API quirk.
            sym_global = theirs.is_global()
            if s.kind != "module" and theirs.is_local() and sym_global:
                sym_global = False
            other = (theirs.is_local(), sym_global, theirs.is_free(),
                     theirs.is_parameter(), theirs.is_imported())
            if ours != other:
                labels = ("local", "global", "free", "parameter", "imported")
                diff = ", ".join("{} ours={} cpython={}".format(k, a, b)
                                 for k, a, b in zip(labels, ours, other) if a != b)
                errors.append("{}:{} {} {}: {}".format(
                    filename, s.lineno, s.kind, source_name, diff))
        # PEP 709 copies symbols of inlined comprehensions into this table.
        # Their comparison was counted as skipped in _pair_tables().
        inlined_names: Set[str] = set()

        def collect_inlined(cid: int) -> None:
            child = table.scopes[cid]
            if not _inline(child):
                return
            inlined_names.update(_mangle(o.name, s._private_class)
                                 for o in table._occurrences
                                 if o.scope == cid and o.active and o.role != "star")
            for grandson in child._children:
                collect_inlined(grandson)

        for child in s._children:
            collect_inlined(child)
        for name in sorted(st.get_identifiers()):
            if (name in names or name in ignore_synthetics or
                    name.startswith(".") or name in inlined_names):
                continue
            errors.append("{}:{} {} {}: extra symtable name".format(
                filename, s.lineno, s.kind, name))
    return report


def verify_against_symtable(source: str, filename: str,
                            table: SymbolTable) -> List[str]:
    """Compare lexical classifications against CPython's symtable.

    Returns only genuine disagreements. Incomparable scopes are counted by
    _verify_detailed() and reported by the command line. Python <=3.14 names
    lambda/comprehension tables 'lambda', 'genexpr', etc.; 3.15+ uses
    '<lambda>', '<genexpr>', etc., all with symtable kind 'function'.
    PEP 709's inlined comprehensions have no separate symtable and are counted
    as skipped comparisons, not silently treated as successful verifications.
    """
    return _verify_detailed(source, filename, table).errors


# SELF TEST -----------------------------------------------------------------

def _self_test() -> None:
    # (source, name, scope kind, resolution); each source is also compared to
    # symtable, so a test is valid only if both checks succeed.
    cases: List[Tuple[str, str, str, str]] = [
        ("x=1\nprint(x)\n", "x", "module", "global"),
        ("def f():\n x=1\n return x\n", "x", "function", "local"),
        ("x=1\ndef f():\n print(x)\n x=2\n", "x", "function", "local"),
        ("def f():\n x=1\n def g():\n  x=2\n  return x\n", "x", "function", "local"),
        ("def f():\n x=1\n def g(): return x\n", "x", "function", "enclosing"),
        ("x=1\nclass C:\n x=2\n def m(self): return x\n", "x", "function", "global"),
        ("def f():\n x=1\n class C:\n  x=2\n  def m(self): return x\n", "x", "function", "enclosing"),
        ("x=1\nclass C:\n y=x\n", "x", "class", "global"),
        ("class C:\n x=1\n y=x\n", "x", "class", "local"),
        ("class C:\n x=[1]\n y=[a for a in x]\n", "x", "class", "local"),
        ("class C:\n x=[1]\n y=[a for a in x if x]\n", "x", "comprehension", "builtin_or_unknown"),
        ("def f(xs):\n return [i for i in xs]\n", "i", "comprehension", "local"),
        ("def f(xs):\n return {i for i in xs}\n", "i", "comprehension", "local"),
        ("def f(xs):\n return {i:i for i in xs}\n", "i", "comprehension", "local"),
        ("def f(xs):\n return (i for i in xs)\n", "i", "comprehension", "local"),
        ("def f(xs):\n return [i for i in xs if i]\n", "i", "comprehension", "local"),
        ("def f(xs):\n y=[(z:=i) for i in xs]\n return z\n", "z", "comprehension", "enclosing"),
        ("def f(xs):\n return [b for a in xs for b in a]\n", "b", "comprehension", "local"),
        ("x=1\ndef f():\n global x\n return x\n", "x", "function", "global"),
        ("def f():\n global missing\n return missing\n", "missing", "function", "global"),
        ("def f():\n x=1\n def g():\n  nonlocal x\n  x=2\n", "x", "function", "enclosing"),
        ("def f():\n x=1\n def g():\n  def h(): return x\n", "x", "function", "enclosing"),
        ("global x\nx=1\n", "x", "module", "global"),
        ("import os.path\nprint(os)\n", "os", "module", "global"),
        ("import os.path as osp\nprint(osp)\n", "osp", "module", "global"),
        ("from os import path as p\nprint(p)\n", "p", "module", "global"),
        ("from os import *\nprint(q)\n", "q", "module", "builtin_or_unknown"),
        ("def f(x, /, y=1, *args, z=1, **kw): return kw\n", "kw", "function", "local"),
        ("x=2\nf=lambda a=x:a\n", "x", "module", "global"),
        ("f=lambda a:a\n", "a", "lambda", "local"),
        ("x=2\ndef f(x): return x\n", "x", "function", "local"),
        ("x=1\ndef dec(f): return f\n@dec\ndef f():\n dec=2\n", "dec", "module", "global"),
        ("def f():\n return f'{item}'\n", "item", "function", "builtin_or_unknown"),
        ("def f():\n del x\n return x\n", "x", "function", "local"),
        ("def f():\n x+=1\n", "x", "function", "local"),
        ("def f():\n for x in []: pass\n return x\n", "x", "function", "local"),
        ("async def f(xs):\n async for x in xs: pass\n return x\n", "x", "function", "local"),
        ("def f(ctx):\n with ctx as (x, y): pass\n return y\n", "y", "function", "local"),
        ("def f():\n try: pass\n except ValueError as e: pass\n return e\n", "e", "function", "local"),
        ("def f():\n x: int\n return x\n", "x", "function", "local"),
        ("def f():\n x: int = 1\n return x\n", "x", "function", "local"),
        ("def f(x):\n x.a=1\n x[0]=2\n", "x", "function", "local"),
        ("class C:\n def m(self): return __class__\n", "__class__", "function", "enclosing"),
        ("def f():\n a=1\n return [j for j in range(a)]\n", "a", "function", "local"),
        ("x=1\ndef f(a=x)->int: return a\n", "x", "module", "global"),
        ("x=1\nclass C(x): pass\n", "x", "module", "global"),
        ("def f():\n x=1\n def g(): return (lambda: x)()\n", "x", "lambda", "enclosing"),
        ("from __future__ import annotations\ndef f(x: T) -> U: return x\n", "x", "function", "local"),
        ("z=[(w:=i) for i in data]\nprint(w)\n", "w", "comprehension", "global"),
        ("def f():\n z=[(w:=i) for i in data]\n return w\n", "w", "function", "local"),
        ("def f():\n x=1\n def g():\n  nonlocal x\n  def h():\n   nonlocal x\n   x=2\n", "x", "function", "enclosing"),
    ]
    if hasattr(ast, "Match"):
        cases += [
            ("def f():\n match 1:\n  case x: return x\n", "x", "function", "local"),
            ("def f():\n match {}:\n  case {'a': x, **r}: return r\n", "r", "function", "local"),
            ("def f():\n match []:\n  case [*rest]: return rest\n", "rest", "function", "local"),
        ]
    if hasattr(ast, "TryStar"):
        cases.append(("def f():\n try: raise ExceptionGroup('x',[ValueError()])\n except* ValueError as e: print(e)\n",
                      "e", "function", "local"))
    if hasattr(ast, "TypeAlias"):
        cases += [
            ("type A = list[int]\n", "list", "type_params", "builtin_or_unknown"),
            ("type A[T] = list[T]\n", "T", "type_params", "enclosing"),
            ("def f[T](x:T)->T: return x\n", "x", "function", "local"),
            ("class C[T]:\n def f(self)->T: return T\n", "T", "function", "enclosing"),
            ("x=1\ndef f[T](y:T=x)->T: return y\n", "x", "module", "global"),
            ("class C:\n X=1\n type A = list[X]\n", "X", "type_params", "enclosing"),
            ("class C:\n X=[1]\n type A = [v for v in X if X]\n", "X", "comprehension", "builtin_or_unknown"),
            ("class C[__T]:\n def f(self) -> __T: return __T\n", "__T", "type_params",
             "enclosing" if sys.version_info >= (3, 14) else "local"),
        ("f=lambda x:(z for z in x)\n", "z", "comprehension", "local"),
        ("def f():\n a=(lambda x:x); b=(lambda y:y)\n", "b", "function", "local"),
        ("def f():\n x: int\n y: str\n return x\n", "x", "function", "local"),
        ("class C:\n x: int\n y: str\n", "x", "class", "local"),
        ("class C:\n X=1\n def f(self, x:X)->X: return x\n", "X",
             "type_params" if sys.version_info >= (3, 14) else "class",
             "enclosing" if sys.version_info >= (3, 14) else "local"),
        ("from __future__ import annotations\nclass C:\n X=1\n y:X\n", "y", "class", "local"),
        ("x: int\n", "x", "module", "global"),
        ]
    if hasattr(ast, "TypeAlias") and sys.version_info >= (3, 13):
        # PEP 696 type-parameter defaults are not valid syntax in 3.12.
        cases.append(("type A[T: int = str] = list[T]\n",
                      "T", "type_params", "enclosing"))
    failures: List[str] = []
    skipped = 0
    for idx, (src, name, kind, expected) in enumerate(cases, 1):
        try:
            tree = ast.parse(src, filename="<self-test:{}>".format(idx))
            t = analyze(tree)
            hits = [o for o in t._occurrences if o.name == name
                    and t.scopes[o.scope].kind == kind and o.role != "global"
                    and o.role != "nonlocal"]
            if not hits:
                raise AssertionError("no occurrence of {} in {}".format(name, kind))
            reads = [o for o in hits if o.role == "load"]
            hit = reads[0] if reads else hits[-1]
            actual = getattr(hit.node, "_resolution", None)
            if actual != expected:
                raise AssertionError("{} in {}: expected {}, got {}".format(
                    name, kind, expected, actual))
            if idx == 63:
                # This is a declaration in the class's type-parameter scope,
                # with subsequent enclosing *uses* in function annotations
                # (3.14+). Both must point at the same owner binding.
                sites = [o for o in hits if o.how == "type_param"]
                assert len(sites) == 1
                assert sites[0].node._resolution == "local"
                owner_id = sites[0].node._binding
                assert all(o.node._binding == owner_id for o in hits)
            report = _verify_detailed(src, "<self-test:{}>".format(idx), t)
            if report.errors:
                raise AssertionError("symtable: " + "; ".join(report.errors))
            skipped += report.skipped
        except Exception as exc:
            failures.append("case {}: {}\n  source: {!r}".format(idx, exc, src))
    if failures:
        raise AssertionError("{} / {} self-tests failed:\n{}".format(
            len(failures), len(cases), "\n".join(failures)))
    print("ok: {} resolver cases; skipped {} symtable comparisons".format(
        len(cases), skipped))


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", metavar="FILE")
    parser.add_argument("--verify", action="store_true",
                        help="compare name classifications with CPython symtable")
    parser.add_argument("--json", action="store_true", help="print each symbol table as JSON")
    parser.add_argument("--self-test", action="store_true", help="run built-in scoping tests")
    args = parser.parse_args(argv)
    if args.self_test:
        _self_test()
        return 0
    if not args.files:
        parser.error("provide FILE... or --self-test")
    failed = False
    total_skipped = 0
    parsed_skipped = 0
    for path in args.files:
        try:
            with tokenize.open(path) as stream:
                src = stream.read()
            tree = ast.parse(src, filename=path, type_comments=True)
        except (SyntaxError, UnicodeError) as exc:
            print("syntax {}: {}".format(path, exc))
            parsed_skipped += 1
            continue
        except OSError as exc:
            print("error {}: {}".format(path, exc), file=sys.stderr)
            failed = True
            continue
        t = analyze(tree)
        if args.verify:
            report = _verify_detailed(src, path, t)
            total_skipped += report.skipped
            if report.errors:
                failed = True
                for item in report.errors:
                    print(item)
            elif not any("symtable rejected input" in r for r in report.reasons):
                print("ok {} (skipped {} symtable comparisons)".format(
                    path, report.skipped))
            # Explain the exceptional skips, without silently passing them.
            for reason in report.reasons:
                if "symtable rejected input" in reason or "ambiguous" in reason:
                    print("skipped {}: {}".format(path, reason))
        if args.json:
            print(json.dumps(t.to_json(), sort_keys=False, separators=(",", ":")))
    if args.verify:
        print("verify: skipped {} symtable comparisons; {} syntax-skipped files".format(
            total_skipped, parsed_skipped))
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())