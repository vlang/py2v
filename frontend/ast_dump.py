#!/usr/bin/env python3
"""
frontend/ast_dump.py
--------------------
Parses a Python source file into an enriched AST and outputs JSON
for the py2v V-side transpiler.

Enrichments beyond standard ast.parse():
  - node_type field on every node (named to avoid V json2's `_type`
    sumtype discriminator, which would make decode[json2.Any] fail)
  - mutable_vars, is_void, is_generator on FunctionDef
  - is_class_method, class_name on methods
  - is_mutable on Name nodes
  - redefined_targets on Assign nodes
  - level (nesting depth) on For/While/If
  - docstring_comment on Module
  - __main__ guard rewritten to main() function
  - condition_walrus_names and lower_condition_walrus for enclosing-scope lowering

Usage:
    python frontend/ast_dump.py <source.py>
"""

import ast
import copy
import functools
import json
import sys
import os
import unicodedata
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set, Tuple, Union

import infer
import symbols


@dataclass
class AnalysisContext:
    """Per-file analysis results threaded through _node_to_dict.

    Replaces module-level mutable globals to prevent inter-file state
    pollution when processing multiple files in the same interpreter session.
    """
    var_annotations: Dict[str, str] = field(default_factory=dict)
    func_ret_annotations: Dict[str, str] = field(default_factory=dict)
    slots_by_class: Dict[str, ast.expr] = field(default_factory=dict)
    field_types: Dict[str, str] = field(default_factory=dict)
    class_field_types: Dict[str, Dict[str, str]] = field(default_factory=dict)
    # Lexical bindings of the file (symbols.analyze), or None when it could not be resolved.
    table: Optional[symbols.SymbolTable] = None
    # Types of the file (infer.run), or None when they could not be inferred.
    facts: Optional[Any] = None

    def scalar_annotation(self, node: ast.AST) -> str:
        """`int`, `float`, `string` or `bool` when that is the type of the expression (the
        type the code shows, else the one its annotations declare), else an empty string."""
        if self.facts is None:
            return ""
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is None:
            return ""
        kind = self.facts.types[type_id]["k"]
        if kind == "list":
            # a list of str or of bool, where the element type is exact
            elem = self.facts.types[type_id].get("elem")
            inner = self.facts.types[elem]["k"] if isinstance(elem, int) else ""
            return {"str": "[]string", "bool": "[]bool"}.get(inner, "")
        if kind == "int" and self._holds_declared_float(node):
            # `x: float` called with 1 holds an int in Python, but V declares it f64
            return ""
        return {"int": "int", "float": "float", "str": "string", "bool": "bool"}.get(kind, "")

    def _holds_declared_float(self, node: ast.AST) -> bool:
        for part in ast.walk(node):
            binding_id = getattr(part, "_binding", None) if isinstance(part, ast.Name) else None
            if binding_id is None or binding_id >= len(self.facts.bindings):
                continue
            declared = self.facts.bindings[binding_id].get("declared")
            if declared is not None and self.facts.types[declared]["k"] == "float":
                return True
        return False

    def native_map_annotation(self, node: ast.AnnAssign) -> Optional[str]:
        """A populated local map keeps the concrete type of its emitted initializer."""
        if self.table is None or self.facts is None or not isinstance(node.target, ast.Name):
            return None
        binding_id = getattr(node.target, "_binding", None)
        if binding_id is None:
            return None
        binding = self.table.bindings[binding_id]
        if (binding.is_param or len(binding.sites) != 1
                or self.table.scopes[binding.scope].kind != "function"):
            return None
        declared = self.facts.bindings[binding_id].get("declared")
        if declared is None or self.facts.types[declared]["k"] != "dict":
            return None
        value_kind = self.facts.types[self.facts.types[declared]["value"]]["k"]
        if value_kind not in ("unknown", "dynamic"):
            return None
        if not isinstance(node.value, ast.Dict) or not node.value.keys or None in node.value.keys:
            return None
        actual = getattr(node.value, "_represented", None)
        return _annotation_for_type(self.facts.types, actual) if actual is not None else None

    def owned_names(self, scope_node: ast.AST) -> Set[str]:
        """Names the scope that `scope_node` opens binds itself: its parameters and locals."""
        scope_id = getattr(scope_node, "_scope_id", None)
        if self.table is None or scope_id is None:
            return set()
        return {b.name for b in self.table.bindings if b.scope == scope_id}

    def rebound_parameters(self, scope_node: ast.AST) -> Set[str]:
        """Parameters of the function that its body binds again (`n -= 1`, `x = lo`)."""
        scope_id = getattr(scope_node, "_scope_id", None)
        if self.table is None or scope_id is None:
            return set()
        return {b.name for b in self.table.bindings
                if b.scope == scope_id and b.is_param and b.rebound}

    @staticmethod
    def empty() -> "AnalysisContext":
        """Return a fresh context with no annotations."""
        return AnalysisContext()


# ---------------------------------------------------------------------------
# Analysis passes
# ---------------------------------------------------------------------------

class ScopeTracker(ast.NodeVisitor):
    """Track variable assignments per scope to detect mutability and redefinitions."""

    # Names of methods, of classes in the file being processed, that change `self`.
    mutating_methods: Set[str] = set()
    # For each function of the file that changes a parameter in place: the positions of
    # those parameters. The backend passes them with `mut`, so the caller's variable
    # needs `mut` too.
    mutating_functions: Dict[str, Set[int]] = {}

    def __init__(self):
        self.scopes: List[Dict[str, List[ast.AST]]] = [{}]
        self.mutable: Set[str] = set()

    def _current(self) -> Dict[str, List[ast.AST]]:
        return self.scopes[-1]

    def _record_assign(self, name: str, node: ast.AST):
        scope = self._current()
        if name not in scope:
            scope[name] = []
        scope[name].append(node)
        if len(scope[name]) > 1:
            self.mutable.add(name)

    def visit_AugAssign(self, node: ast.AugAssign):
        # `x[i] += 1` and `self.x += 1` store into x and self as `x[i] = ...`
        # and `self.x = ...` do, so they need the same `mut`.
        self._check_subscript_assign(node.target)
        for name in _extract_names(node.target):
            self._record_assign(name, node)
            self.mutable.add(name)
        self.generic_visit(node)

    def visit_AnnAssign(self, node: ast.AnnAssign):
        if node.target:
            if node.value is not None:
                # `self.x: T = v` stores into self as `self.x = v` does
                self._check_subscript_assign(node.target)
            for name in _extract_names(node.target):
                self._record_assign(name, node)
        self.generic_visit(node)

    def visit_For(self, node: ast.For):
        for name in _extract_names(node.target):
            self._record_assign(name, node)
            self.mutable.add(name)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call):
        """Detect mutating method calls like x.append(), x.insert(), etc."""
        _MUTATING_METHODS = {
            'append', 'insert', 'remove', 'extend',
            'sort', 'reverse', 'pop', 'clear',
        }
        # A method of a class in this file that changes its object changes the caller's
        # variable too: `c.add(1)` needs `mut c` as `c.total += 1` does.
        if (isinstance(node.func, ast.Attribute)
                and (node.func.attr in _MUTATING_METHODS
                     or node.func.attr in self.mutating_methods)
                and isinstance(node.func.value, ast.Name)):
            self.mutable.add(node.func.value.id)
            self._record_assign(node.func.value.id, node)
        # `self.items.append(x)` and `self.items.pop()` change self through its field.
        elif (isinstance(node.func, ast.Attribute)
                and (node.func.attr in _MUTATING_METHODS or node.func.attr == 'pop')
                and isinstance(node.func.value, ast.Attribute)
                and isinstance(node.func.value.value, ast.Name)
                and node.func.value.value.id == 'self'):
            self.mutable.add('self')
            self._record_assign('self', node)
        # `groups[key].append(x)` changes `groups` through its element.
        elif (isinstance(node.func, ast.Attribute)
                and node.func.attr in _MUTATING_METHODS
                and isinstance(node.func.value, ast.Subscript)):
            root = node.func.value
            while isinstance(root, ast.Subscript):
                root = root.value
            if isinstance(root, ast.Attribute) and isinstance(root.value, ast.Name) \
                    and root.value.id == 'self':
                root = root.value
            if isinstance(root, ast.Name):
                self.mutable.add(root.id)
                self._record_assign(root.id, node)
        # `random.shuffle(xs)` reorders xs in place.
        if ((isinstance(node.func, ast.Attribute) and node.func.attr == 'shuffle'
                and isinstance(node.func.value, ast.Name) and node.func.value.id == 'random')
                or getattr(node.func, '_math_member', '') == 'random.shuffle') \
                and node.args and isinstance(node.args[0], ast.Name):
            self.mutable.add(node.args[0].id)
            self._record_assign(node.args[0].id, node)
        # `f(xs)` where f changes that parameter in place: `xs` is passed with `mut`.
        if isinstance(node.func, ast.Name) and node.func.id in self.mutating_functions \
                and not any(isinstance(arg, ast.Starred) for arg in node.args):
            for index in self.mutating_functions[node.func.id]:
                if index < len(node.args) and isinstance(node.args[index], ast.Name):
                    self.mutable.add(node.args[index].id)
                    self._record_assign(node.args[index].id, node)
        self.generic_visit(node)

    def visit_Delete(self, node: ast.Delete):
        """Process del statement - don't mark as mutable since @[translated] relaxes this."""
        self.generic_visit(node)

    def _check_subscript_assign(self, target: ast.AST):
        """A store into an element or attribute makes the variable it starts from
        mutable: x[i] = ..., x[i:j] = ..., x.attr = ..., and nested stores such as
        x[i][j] = ... or self.items[0] = ..., which reach x or self through more
        than one subscript or attribute. A store straight into a slice
        (x[:][0] = ...) changes only the copy, so it leaves x unchanged; one that
        goes on into the copy's elements (grid[:][0][0] = ...) reaches the
        original rows, so it still counts."""
        if isinstance(target, (ast.Subscript, ast.Attribute)):
            container = target.value
            if isinstance(container, ast.Subscript) and isinstance(container.slice, ast.Slice):
                return
            root = container
            while isinstance(root, (ast.Subscript, ast.Attribute)):
                root = root.value
            if isinstance(root, ast.Name):
                self.mutable.add(root.id)
                self._record_assign(root.id, target)
        elif isinstance(target, (ast.Tuple, ast.List)):
            for elt in target.elts:
                self._check_subscript_assign(elt)

    def visit_Assign(self, node: ast.Assign):
        for target in node.targets:
            self._check_subscript_assign(target)
            for name in _extract_names(target):
                self._record_assign(name, node)
        self.generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef):
        self.scopes.append({})
        self.generic_visit(node)
        self.scopes.pop()

    visit_AsyncFunctionDef = visit_FunctionDef


def _extract_names(node: ast.AST) -> List[str]:
    """Extract all Name ids from an assignment target."""
    if isinstance(node, ast.Name):
        return [node.id]
    if isinstance(node, (ast.Tuple, ast.List)):
        names = []
        for elt in node.elts:
            names.extend(_extract_names(elt))
        return names
    if isinstance(node, ast.Starred):
        return _extract_names(node.value)
    return []


def _is_void_function(node: ast.FunctionDef) -> bool:
    """Check if a function never returns a value."""
    # If there's a return type annotation, it's not void
    if node.returns is not None:
        return False
    for child in ast.walk(node):
        if isinstance(child, ast.Return) and child.value is not None:
            return False
        if isinstance(child, ast.Yield) or isinstance(child, ast.YieldFrom):
            return False
    return True


def _is_generator(node: ast.FunctionDef) -> bool:
    for child in ast.walk(node):
        if isinstance(child, (ast.Yield, ast.YieldFrom)):
            return True
    return False


def _infer_type_from_value(node: ast.AST) -> str:
    """Infer a type string from a value expression."""
    if isinstance(node, ast.Constant):
        if isinstance(node.value, bool):
            return "bool"
        if isinstance(node.value, int):
            return "int"
        if isinstance(node.value, float):
            return "float"
        if isinstance(node.value, str):
            return "str"
    if isinstance(node, ast.List):
        return "list"
    if isinstance(node, ast.Dict):
        return "dict"
    # For None literal (ast.Constant with value=None)
    if isinstance(node, ast.Constant) and node.value is None:
        return ""
    return ""


def _infer_homogeneous_dict_value_type(node: ast.Dict) -> str:
    """Infer dict value type when all values share a simple primitive type."""
    value_types: Set[str] = set()
    for v in node.values:
        if v is None:
            continue
        typ = _infer_type_from_value(v)
        if typ:
            value_types.add(typ)
    if len(value_types) == 1:
        return next(iter(value_types))
    return ""


def _normalize_inferred_type_name(typ: str) -> str:
    if typ == "str":
        return "string"
    if typ == "float":
        return "f64"
    return typ


def _infer_nested_function_type(fn: ast.FunctionDef) -> str:
    """Infer a V-style function type for a nested function definition."""
    param_types: List[str] = []
    for a in fn.args.args:
        if a.annotation is not None:
            ann = _annotation_to_str(a.annotation)
            param_types.append(_normalize_inferred_type_name(ann if ann else "Any"))
        else:
            param_types.append("Any")

    if fn.returns is not None:
        ret = _annotation_to_str(fn.returns)
        ret_type = _normalize_inferred_type_name(ret if ret else "Any")
    else:
        inferred = _infer_return_type(fn)
        ret_type = inferred if inferred else "Any"

    return f"fn ({', '.join(param_types)}) {ret_type}"


def _collect_returns_excluding_nested(node: ast.FunctionDef) -> List[ast.Return]:
    """Collect return statements in a function body, excluding nested functions."""

    class ReturnCollector(ast.NodeVisitor):
        def __init__(self):
            self.returns: List[ast.Return] = []

        def visit_Return(self, n: ast.Return):
            self.returns.append(n)

        def visit_FunctionDef(self, n: ast.FunctionDef):
            # Skip nested functions when inferring parent return type.
            return

        visit_AsyncFunctionDef = visit_FunctionDef

    collector = ReturnCollector()
    for stmt in node.body:
        collector.visit(stmt)
    return collector.returns


def _merge_local_type(local_types: Dict[str, str], name: str, typ: str):
    """Merge a discovered local type conservatively.

    If conflicting types are seen for the same name, clear inference for that name.
    """
    prev = local_types.get(name, "")
    if not prev:
        local_types[name] = typ
        return
    if prev != typ:
        local_types.pop(name, None)


def _collect_local_assignment_types_from_stmts(
    stmts: List[ast.stmt],
    local_types: Dict[str, str],
    local_dict_value_types: Dict[str, str],
):
    """Collect simple assignment type hints from nested blocks in a function body."""
    for stmt in stmts:
        if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
            name = stmt.targets[0].id
            typ = _infer_type_from_value(stmt.value)
            if typ:
                _merge_local_type(local_types, name, typ)
            if isinstance(stmt.value, ast.Dict):
                dict_value_typ = _infer_homogeneous_dict_value_type(stmt.value)
                if dict_value_typ:
                    prev = local_dict_value_types.get(name, "")
                    if not prev:
                        local_dict_value_types[name] = dict_value_typ
                    elif prev != dict_value_typ:
                        local_dict_value_types.pop(name, None)
        elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) and stmt.annotation is not None:
            ann = _annotation_to_str(stmt.annotation)
            if ann:
                _merge_local_type(local_types, stmt.target.id, _normalize_inferred_type_name(ann))
            if isinstance(stmt.value, ast.Dict):
                dict_value_typ = _infer_homogeneous_dict_value_type(stmt.value)
                if dict_value_typ:
                    prev = local_dict_value_types.get(stmt.target.id, "")
                    if not prev:
                        local_dict_value_types[stmt.target.id] = dict_value_typ
                    elif prev != dict_value_typ:
                        local_dict_value_types.pop(stmt.target.id, None)
        elif isinstance(stmt, ast.If):
            _collect_local_assignment_types_from_stmts(stmt.body, local_types, local_dict_value_types)
            _collect_local_assignment_types_from_stmts(stmt.orelse, local_types, local_dict_value_types)
        elif isinstance(stmt, (ast.For, ast.AsyncFor, ast.While)):
            _collect_local_assignment_types_from_stmts(stmt.body, local_types, local_dict_value_types)
            _collect_local_assignment_types_from_stmts(stmt.orelse, local_types, local_dict_value_types)
        elif isinstance(stmt, (ast.With, ast.AsyncWith)):
            _collect_local_assignment_types_from_stmts(stmt.body, local_types, local_dict_value_types)
        elif isinstance(stmt, ast.Try):
            _collect_local_assignment_types_from_stmts(stmt.body, local_types, local_dict_value_types)
            _collect_local_assignment_types_from_stmts(stmt.orelse, local_types, local_dict_value_types)
            _collect_local_assignment_types_from_stmts(stmt.finalbody, local_types, local_dict_value_types)
            for h in stmt.handlers:
                _collect_local_assignment_types_from_stmts(h.body, local_types, local_dict_value_types)


def _infer_return_type(node: ast.FunctionDef) -> str:
    """Infer the return type from a function's return statements.

    Returns a type string (e.g., 'int', 'bool', 'string') if all returns
    consistently resolve to one type. Returns empty string when inference is
    ambiguous.
    """
    if node.returns is not None:
        return ""

    # Track simple local assignment types to resolve `return name` and
    # `return mapping[key]` patterns.
    local_types: Dict[str, str] = {}
    local_dict_value_types: Dict[str, str] = {}
    nested_function_types: Dict[str, str] = {}
    for stmt in node.body:
        if isinstance(stmt, ast.FunctionDef):
            nested_function_types[stmt.name] = _infer_nested_function_type(stmt)

    _collect_local_assignment_types_from_stmts(node.body, local_types, local_dict_value_types)
    for name, typ in getattr(node, "_condition_walrus_hints", {}).items():
        local_types.setdefault(name, typ)

    return_types: Set[str] = set()
    saw_none_return = False
    for ret_stmt in _collect_returns_excluding_nested(node):
        if ret_stmt.value is None:
            continue

        expr = ret_stmt.value

        if isinstance(expr, ast.Constant) and expr.value is None:
            saw_none_return = True
            continue

        # Comparisons return bool; boolean operations return a selected operand.
        if isinstance(expr, ast.Compare):
            return_types.add("bool")
            continue

        typ = _infer_type_from_value(expr)
        if typ:
            return_types.add(typ)
            continue

        if isinstance(expr, ast.Name):
            local_typ = local_types.get(expr.id, "")
            if local_typ:
                return_types.add(local_typ)
                continue
            nested_fn_typ = nested_function_types.get(expr.id, "")
            if nested_fn_typ:
                return_types.add(nested_fn_typ)
                continue
            return ""

        if isinstance(expr, ast.Subscript) and isinstance(expr.value, ast.Name):
            value_typ = local_dict_value_types.get(expr.value.id, "")
            if value_typ:
                return_types.add(value_typ)
                continue
            return ""

        # Keep inference conservative for calls and complex expressions.
        return ""

    if not return_types or len(return_types) > 1:
        return ""

    ret = next(iter(return_types))
    if ret == "str":
        return "string"
    return ret


def _has_main_guard(tree: ast.Module) -> Optional[ast.If]:
    """Find `if __name__ == "__main__":` at the module level."""
    for node in tree.body:
        if isinstance(node, ast.If):
            test = node.test
            if (isinstance(test, ast.Compare)
                    and isinstance(test.left, ast.Name)
                    and test.left.id == "__name__"
                    and len(test.ops) == 1
                    and isinstance(test.ops[0], ast.Eq)
                    and len(test.comparators) == 1
                    and isinstance(test.comparators[0], ast.Constant)
                    and test.comparators[0].value == "__main__"):
                return node
    return None


def _rewrite_main_guard(tree: ast.Module) -> ast.Module:
    """Replace `if __name__ == "__main__":` with `def main():`.

    If the module already defines a `def main()`, rename it to `main_func()`
    and update any calls to `main()` inside the guard body accordingly.
    """
    guard = _has_main_guard(tree)
    if guard is None:
        return tree

    # Check if there's already a def main() at module level
    has_existing_main = any(
        isinstance(node, ast.FunctionDef) and node.name == "main"
        for node in tree.body if node is not guard
    )

    if has_existing_main:
        # Rename existing def main() -> def main_func()
        for node in tree.body:
            if isinstance(node, ast.FunctionDef) and node.name == "main":
                node.name = "main_func"

        # Rename calls to main() -> main_func() in the guard body
        _rename_calls(guard, "main", "main_func")

    main_func = ast.FunctionDef(
        name="main",
        args=ast.arguments(
            posonlyargs=[], args=[], kwonlyargs=[],
            kw_defaults=[], defaults=[], vararg=None, kwarg=None,
        ),
        body=guard.body,
        decorator_list=[],
        returns=None,
        type_params=[],
        lineno=guard.lineno,
        col_offset=guard.col_offset,
        end_lineno=guard.end_lineno,
        end_col_offset=guard.end_col_offset,
    )

    new_body = []
    for node in tree.body:
        if node is guard:
            new_body.append(main_func)
        else:
            new_body.append(node)
    tree.body = new_body
    return tree


def _rename_calls(node: ast.AST, old_name: str, new_name: str):
    """Rename all calls to `old_name()` to `new_name()` within a node."""
    for child in ast.walk(node):
        if (isinstance(child, ast.Call)
                and isinstance(child.func, ast.Name)
                and child.func.id == old_name):
            child.func.id = new_name


def _plan_condition_walruses(tree: ast.Module):
    """Select broken if conditions without changing already working lowering.

    Only the operators handled by the backend's statement lowering are selected.
    Names belong to the surrounding module or function, not to a generated block.
    Literal type hints are limited to selected locals with no other bindings.
    """
    nested_expressions = (ast.Lambda, ast.ListComp, ast.SetComp,
                          ast.DictComp, ast.GeneratorExp)
    function_scopes = (ast.FunctionDef, ast.AsyncFunctionDef)
    nested_scopes = function_scopes + (ast.ClassDef, ast.Lambda)
    try_nodes = (ast.Try, getattr(ast, "TryStar", ast.Try))
    external_names: Set[str] = set()

    def contains(expr):
        if isinstance(expr, ast.NamedExpr):
            return True
        if isinstance(expr, nested_expressions):
            return False
        return any(contains(child) for child in ast.iter_child_nodes(expr))

    def supported(expr):
        if not contains(expr):
            return True
        if not isinstance(expr, (ast.NamedExpr, ast.UnaryOp, ast.BinOp,
                                 ast.BoolOp, ast.Compare)):
            return False
        if isinstance(expr, ast.NamedExpr):
            if not isinstance(expr.target, ast.Name):
                return False
        return all(supported(child) for child in ast.iter_child_nodes(expr))

    def emitted_walrus(expr):
        # The existing comparison visitor ignores links after the first one.
        if isinstance(expr, ast.Compare):
            return (emitted_walrus(expr.left)
                    or any(emitted_walrus(c) for c in expr.comparators[:1]))
        if isinstance(expr, ast.NamedExpr):
            return True
        if isinstance(expr, nested_expressions):
            return False
        return any(emitted_walrus(child) for child in ast.iter_child_nodes(expr))

    def legacy_left(test):
        return isinstance(test, ast.Compare) and isinstance(test.left, ast.NamedExpr)

    def select(node, bound, is_elif):
        if not emitted_walrus(node.test) or not supported(node.test):
            return False
        names = []
        targets(node.test, names)
        if external_names.intersection(names):
            return False
        if legacy_left(node.test):
            named = node.test.left
            if not emitted_walrus(named.value) and not emitted_walrus(node.test.comparators[0]):
                return is_elif or named.target.id in bound
        return True

    def targets(expr, names):
        if isinstance(expr, nested_expressions):
            return
        if isinstance(expr, ast.NamedExpr) and expr.target.id not in names:
            names.append(expr.target.id)
        for child in ast.iter_child_nodes(expr):
            targets(child, names)

    def assignment_binds(node):
        value = node.value
        if isinstance(value, ast.Call):
            if isinstance(value.func, (ast.Name, ast.Attribute)):
                name = value.func.id if isinstance(value.func, ast.Name) else value.func.attr
                if name == "TypeVar":
                    return False
            if (len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)
                    and isinstance(value.func, ast.Name) and value.func.id == "namedtuple"):
                return False
        if isinstance(value, ast.Subscript) and isinstance(value.value, (ast.Name, ast.Attribute)):
            name = value.value.id if isinstance(value.value, ast.Name) else value.value.attr
            if name == "Literal":
                return False
        return not (len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)
                    and node.targets[0].id == "__all__" and isinstance(value, ast.List))

    blocks = {}
    scope_of = {}

    def note_blocks(scope):
        compound = (ast.If, ast.For, ast.AsyncFor, ast.While, ast.With, ast.AsyncWith) + try_nodes
        if hasattr(ast, "Match"):
            compound += (ast.Match,)

        def walk(node, block):
            for child in ast.iter_child_nodes(node):
                if isinstance(child, nested_scopes):
                    continue
                if isinstance(child, ast.If):
                    blocks[id(child)] = block
                    scope_of[id(child)] = scope
                walk(child, child if isinstance(child, compound) else block)

        walk(scope, None)

    def hoists_alone(node):
        """True when the backend hoists this bare walrus on its own line and
        that is enough: the target is not `_`, and nothing reads it outside the
        block the hoisted line lands in. Otherwise the name is declared at the
        top of the scope like every other walrus in a condition."""
        test = node.test
        if not (isinstance(test, ast.NamedExpr) and getattr(test, "_hoist", False)):
            return False
        name = test.target.id
        if name == "_":
            return False
        block = blocks.get(id(node))
        if block is None:
            return True
        inside = {id(n) for n in ast.walk(block)}
        return not any(isinstance(n, ast.Name) and n.id == name and isinstance(n.ctx, ast.Load)
                       and id(n) not in inside for n in ast.walk(scope_of[id(node)]))

    def scan(body, bound, names, is_elif=False):
        for node in body:
            if isinstance(node, ast.If):
                hoisted = not is_elif and hoists_alone(node)
                if not hoisted and select(node, bound, is_elif):
                    node._lower_condition_walrus = True
                    targets(node.test, names)
                scan(node.body, set(bound), names)
                elif_tail = len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If)
                scan(node.orelse, set(bound), names, elif_tail)
                if legacy_left(node.test):
                    bound.update(_extract_names(node.test.left.target))
            elif isinstance(node, (ast.For, ast.AsyncFor)):
                scan(node.body, bound | set(_extract_names(node.target)), names)
                scan(node.orelse, set(bound), names)
            elif isinstance(node, ast.While):
                scan(node.body, set(bound), names)
                infinite = isinstance(node.test, ast.Constant) and node.test.value is True
                if not infinite and not legacy_left(node.test):
                    scan(node.orelse, set(bound), names)
            elif isinstance(node, (ast.With, ast.AsyncWith)):
                inner = set(bound)
                for item in node.items:
                    if item.optional_vars is not None:
                        inner.update(_extract_names(item.optional_vars))
                scan(node.body, inner, names)
            elif isinstance(node, try_nodes):
                # The backend emits finally as a defer before the try body.
                # Except handlers and try/else have no generated statement body.
                scan(node.finalbody, set(bound), names)
                scan(node.body, bound, names)
            elif hasattr(ast, "Match") and isinstance(node, ast.Match):
                for arm in node.cases:
                    scan(arm.body, set(bound), names)
            elif isinstance(node, ast.Assign) and assignment_binds(node):
                for target in node.targets:
                    bound.update(_extract_names(target))
            elif isinstance(node, ast.AnnAssign):
                bound.update(_extract_names(node.target))

    def literal_hints(scope, names, parameters):
        hints = {}
        conflicts = set(parameters)

        def visit(node):
            if isinstance(node, ast.NamedExpr):
                name = node.target.id
                typ = _infer_type_from_value(node.value) if isinstance(node.value, ast.Constant) else ""
                if typ not in ("bool", "int", "float", "str") or hints.get(name, typ) != typ:
                    conflicts.add(name)
                else:
                    hints[name] = typ
                visit(node.value)
                return
            if isinstance(node, ast.Name) and isinstance(node.ctx, (ast.Store, ast.Del)):
                conflicts.add(node.id)
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                conflicts.update(a.asname or a.name.split(".")[0] for a in node.names)
                if any(a.name == "*" for a in node.names):
                    conflicts.update(names)
            if isinstance(node, (ast.Global, ast.Nonlocal)):
                conflicts.update(node.names)
            if isinstance(node, (ast.ExceptHandler,) + function_scopes + (ast.ClassDef,)):
                if node.name:
                    conflicts.add(node.name)
            if isinstance(node, function_scopes):
                for declaration in ast.walk(node):
                    if isinstance(declaration, (ast.Global, ast.Nonlocal)):
                        conflicts.update(declaration.names)
            if type(node).__name__ in ("MatchAs", "MatchStar") and node.name:
                conflicts.add(node.name)
            if type(node).__name__ == "MatchMapping" and node.rest:
                conflicts.add(node.rest)
            for field_name, value in ast.iter_fields(node):
                if isinstance(node, nested_scopes) and field_name == "body":
                    continue
                children = value if isinstance(value, list) else [value]
                for child in children:
                    if isinstance(child, ast.AST):
                        visit(child)

        for statement in scope.body:
            visit(statement)
        return {name: hints[name] for name in names if name in hints and name not in conflicts}

    for node in ast.walk(tree):
        if isinstance(node, ast.If):
            node._lower_condition_walrus = False
    scopes = [tree] + [node for node in ast.walk(tree) if isinstance(node, function_scopes)]
    for scope in scopes:
        external_names = set()
        pending = list(scope.body)
        while pending:
            node = pending.pop()
            if isinstance(node, (ast.Global, ast.Nonlocal)):
                external_names.update(node.names)
            elif not isinstance(node, nested_scopes):
                pending.extend(ast.iter_child_nodes(node))
        parameters = []
        if isinstance(scope, function_scopes):
            parameters = [arg.arg for arg in _all_args(scope.args)]
            parameters += [arg.arg for arg in (scope.args.vararg, scope.args.kwarg) if arg is not None]
        names = []
        note_blocks(scope)
        scan(scope.body, set(parameters), names)
        scope._condition_walrus_names = names
        scope._condition_walrus_hints = (literal_hints(scope, names, parameters)
                                         if isinstance(scope, function_scopes) else {})


def _extract_docstring(tree: ast.Module) -> Optional[str]:
    """Extract module-level docstring."""
    if (tree.body
            and isinstance(tree.body[0], ast.Expr)
            and isinstance(tree.body[0].value, ast.Constant)
            and isinstance(tree.body[0].value.value, str)):
        return tree.body[0].value.value
    return None


def _binding_keys(scope: ast.AST, skip: Set[int], into_functions: bool = True) -> Set[str]:
    """The names bound anywhere under `scope` (stores and deletes, parameters,
    def and class names, imports, except-as, global and nonlocal, match
    captures), as loose V spellings: lowercased with outer underscores
    stripped, so names V would spell alike (`_tag`, `tag_`) collide. Nested
    function bodies count unless `into_functions` is false; then only their
    names, decorators and default values are scanned. `*` stands for a star
    import."""
    match_as = tuple(getattr(ast, n) for n in ("MatchAs", "MatchStar") if hasattr(ast, n))
    match_mapping = getattr(ast, "MatchMapping", None)
    funcs = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)
    nodes: List[ast.AST] = []
    stack: List[ast.AST] = [scope]
    while stack:
        n = stack.pop()
        nodes.append(n)
        if n is not scope and isinstance(n, funcs) and not into_functions:
            # Its decorators and default values run in this scope.
            stack.extend(getattr(n, "decorator_list", []))
            stack.extend(n.args.defaults)
            stack.extend(d for d in n.args.kw_defaults if d is not None)
            continue
        stack.extend(ast.iter_child_nodes(n))
    names: List[str] = []
    for n in nodes:
        if id(n) in skip:
            continue
        if isinstance(n, ast.Name) and not isinstance(n.ctx, ast.Load):
            names.append(n.id)
        elif isinstance(n, ast.arg):
            names.append(n.arg)
        elif isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            names.append(n.name)
        elif isinstance(n, ast.alias):
            names.append(n.asname or n.name.split(".")[0])
        elif isinstance(n, ast.ExceptHandler) and n.name:
            names.append(n.name)
        elif isinstance(n, (ast.Global, ast.Nonlocal)):
            names.extend(n.names)
        elif match_as and isinstance(n, match_as) and n.name:
            names.append(n.name)
        elif match_mapping is not None and isinstance(n, match_mapping) and n.rest:
            names.append(n.rest)
    return {x if x == "*" else x.lower().strip("_") for x in names}


def _mark_isinstance_subjects(tree: ast.Module) -> None:
    """Set `_subject_class` on each `isinstance(name, ...)` call whose `name`
    is a parameter of the function the call is in, annotated with one of the
    builtin classes a V type stands for: `int`, `float`, `str`, `bool`, `list`
    or `dict`, or `List`/`Dict` from `typing`, subscripted or not. The value is
    that class name, and the backend decides the call from it.

    The parameter must be bound nowhere else in the function: not assigned,
    not a loop, comprehension, `with`, `except`, walrus or `del` target, not a
    parameter of a nested function or lambda, not a `def`, `class`, import,
    `global`, `nonlocal` or match capture; except that every other binding may
    lie in a statement of the function's body after the one holding the call
    (a call not inside a lambda or generator expression): those statements run
    in order, once, so the call still sees the argument.
    A second-argument class may also be `tuple`, `set` or `bytes`, and so may
    the annotation.

    Also marked: `isinstance(x, ...)` where `x` is the target of a `for` loop
    or comprehension over such a parameter (bound nowhere else at all)
    annotated `list[C]` with C one of the plain classes, the call is in the
    loop's body or the comprehension, and `x` is bound nowhere else in the
    function except by other such loops of the same class C (for a
    comprehension: nowhere else in the comprehension).
    Not marked either: a parameter
    whose default is `None`, positional-only parameters, `*args` and
    `**kwargs`, and a call in the function's own default values, decorators
    or annotations (those see the scope outside).
    Nothing is marked in a module that binds one of the six class names or
    `isinstance` in any way, or has a star import. Module-level code is never
    marked."""
    fn_types = (ast.FunctionDef, ast.AsyncFunctionDef)
    plain_classes = ("int", "float", "str", "bool", "list", "dict", "tuple", "set", "bytes")
    builtin_names = plain_classes + ("isinstance",)
    comprehensions = (ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp)

    def bound_names(node: ast.AST) -> List[str]:
        """The names `node` itself binds, however it binds them."""
        if isinstance(node, ast.Name):
            return [] if isinstance(node.ctx, ast.Load) else [node.id]
        if isinstance(node, ast.arg):
            return [node.arg]
        if isinstance(node, fn_types + (ast.ClassDef,)):
            return [node.name]
        if isinstance(node, ast.alias):
            return [(node.asname or node.name).split(".")[0]]
        if isinstance(node, (ast.Global, ast.Nonlocal)):
            return list(node.names)
        if isinstance(node, ast.ExceptHandler):
            return [node.name] if node.name else []
        if type(node).__name__ in ("MatchAs", "MatchStar"):
            return [node.name] if node.name else []
        if type(node).__name__ == "MatchMapping":
            return [node.rest] if node.rest else []
        return []

    # `List` and `Dict` count only as imported from typing, under their own
    # names, and `typing.List` only through `import typing`.
    typing_modules = set()
    typing_classes = set()
    for node in ast.walk(tree):
        if any(name in builtin_names for name in bound_names(node)):
            return
        if isinstance(node, ast.ImportFrom):
            if any(a.name == "*" for a in node.names):
                return
            if node.module == "typing" and node.level == 0:
                typing_classes.update(a.name for a in node.names
                                      if a.name in ("List", "Dict") and a.asname is None)
        elif isinstance(node, ast.Import):
            typing_modules.update(a.asname or a.name for a in node.names if a.name == "typing")
    module_names = [name for node in ast.walk(tree) for name in bound_names(node)]
    for name in list(typing_classes) + list(typing_modules):
        # Bound once, by that import.
        if module_names.count(name) != 1:
            typing_classes.discard(name)
            typing_modules.discard(name)

    def annotation_class(annotation: Optional[ast.AST]) -> str:
        base = annotation.value if isinstance(annotation, ast.Subscript) else annotation
        if isinstance(base, ast.Name):
            if base.id in plain_classes:
                return base.id
            if base.id in typing_classes:
                return base.id.lower()
        elif (isinstance(base, ast.Attribute) and base.attr in ("List", "Dict")
              and isinstance(base.value, ast.Name) and base.value.id in typing_modules):
            return base.attr.lower()
        return ""

    def element_class(annotation: Optional[ast.AST]) -> str:
        """C for an annotation `list[C]` or `List[C]`, C a plain class."""
        if (isinstance(annotation, ast.Subscript) and annotation_class(annotation) == "list"
                and isinstance(annotation.slice, ast.Name)
                and annotation.slice.id in plain_classes):
            return annotation.slice.id
        return ""

    def count_bindings(root: ast.AST, name: str) -> int:
        return sum(bound_names(node).count(name) for node in ast.walk(root))

    def loop_subject_class(fn: ast.AST, call: ast.Call) -> str:
        """The class of a `for` or comprehension target iterating a parameter
        annotated `list[C]`, for a call inside that loop."""
        name = call.args[0].id

        def iterated(iterable: ast.AST) -> str:
            # A slice of a list holds elements of the list.
            if isinstance(iterable, ast.Subscript) and isinstance(iterable.slice, ast.Slice):
                iterable = iterable.value
            if not isinstance(iterable, ast.Name) or iterable.id == name:
                return ""
            param = next((a for a in fn.args.args + fn.args.kwonlyargs if a.arg == iterable.id), None)
            if param is None or not subject_class(fn, iterable.id, None):
                return ""
            return element_class(param.annotation)

        def holds(root: ast.AST) -> bool:
            return any(node is call for node in ast.walk(root))

        for node in ast.walk(fn):
            if isinstance(node, comprehensions) and holds(node):
                # The innermost comprehension binding the name is the one the call reads.
                inner = [c for c in ast.walk(node) if c is not node
                         and isinstance(c, comprehensions) and holds(c)
                         and count_bindings(c, name)]
                if inner or count_bindings(node, name) != 1:
                    continue
                for generator in node.generators:
                    if isinstance(generator.target, ast.Name) and generator.target.id == name:
                        if count_bindings(node, getattr(generator.iter, "id", "")):
                            return ""
                        return iterated(generator.iter)
        # Every binding of the name is a `for` target over such a parameter,
        # all of one class, and the call is in the body of one of the loops.
        loops = [node for node in ast.walk(fn) if isinstance(node, ast.For)
                 and isinstance(node.target, ast.Name) and node.target.id == name]
        classes = {iterated(loop.iter) for loop in loops}
        if (count_bindings(fn, name) != len(loops) or len(classes) != 1
                or not any(holds(s) for loop in loops for s in loop.body)):
            return ""
        return classes.pop()

    def subject_class(fn: ast.AST, name: str, call: Optional[ast.AST]) -> str:
        args = fn.args
        positional = args.posonlyargs + args.args
        defaults = dict(zip([a.arg for a in positional[len(positional) - len(args.defaults):]],
                            args.defaults))
        defaults.update({a.arg: d for a, d in zip(args.kwonlyargs, args.kw_defaults) if d is not None})
        param = next((a for a in args.args + args.kwonlyargs if a.arg == name), None)
        if param is None:
            return ""
        default = defaults.get(name)
        if isinstance(default, ast.Constant) and default.value is None:
            return ""
        # Statements of the body after the one holding the call may rebind it.
        later: List[ast.stmt] = []
        if call is not None:
            for i, statement in enumerate(fn.body):
                if any(node is call for node in ast.walk(statement)):
                    # A lambda or generator expression may run the call later.
                    lazy = any(isinstance(part, (ast.Lambda, ast.GeneratorExp))
                               and any(node is call for node in ast.walk(part))
                               for part in ast.walk(statement))
                    later = [] if lazy else fn.body[i + 1:]
                    break
        allowed = {id(node) for statement in later for node in ast.walk(statement)}
        for node in ast.walk(fn):
            if (node is not fn and node is not param and id(node) not in allowed
                    and name in bound_names(node)):
                return ""
        return annotation_class(param.annotation)

    def mark(node: ast.AST, fn: Optional[ast.AST]) -> None:
        if (fn is not None and isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name) and node.func.id == "isinstance"
                and len(node.args) == 2 and not node.keywords
                and isinstance(node.args[0], ast.Name)):
            node._subject_class = (subject_class(fn, node.args[0].id, node)
                                   or loop_subject_class(fn, node))

    def visit(node: ast.AST, fn: Optional[ast.AST]) -> None:
        if isinstance(node, fn_types):
            # Only the body runs with the parameters bound: defaults,
            # decorators and annotations belong to the scope outside.
            for part in node.decorator_list + [node.args] + ([node.returns] if node.returns else []):
                visit(part, fn)
            for statement in node.body:
                visit(statement, node)
        else:
            mark(node, fn)
            for child in ast.iter_child_nodes(node):
                visit(child, fn)

    visit(tree, None)


def _detect_walrus_hoists(tree: ast.Module):
    """Set `_hoist` on each NamedExpr that is the whole test of an `if`: true
    only when nothing else binds its name (in its outermost enclosing function,
    nested functions included, and at module level, the `__main__` guard block
    included since this runs before that block becomes a function; for a
    module-level `if`, anywhere in the file), and no function there without a
    return annotation, nor a lambda, returns the name.
    The transpiler hoists only those; every other walrus keeps its old form."""
    module_keys = _binding_keys(tree, set(), into_functions=False)

    def check(test: ast.NamedExpr, fn: Optional[ast.AST]):
        name = test.target.id
        key = name.lower().strip("_")
        skip = {id(test.target)}
        if fn is None:
            keys = _binding_keys(tree, skip)
        else:
            keys = _binding_keys(fn, skip) | module_keys
        if key in keys or "*" in keys:
            return False
        # No function in that scope (the whole module for a module-level `if`)
        # without a return annotation may return the name, nor any lambda.
        for f in ast.walk(fn if fn is not None else tree):
            if isinstance(f, ast.Lambda):
                values = [f.body]
            elif isinstance(f, (ast.FunctionDef, ast.AsyncFunctionDef)) and f.returns is None:
                values = [r.value for r in ast.walk(f) if isinstance(r, ast.Return) and r.value is not None]
            else:
                continue
            for v in values:
                if any(isinstance(x, ast.Name) and x.id == name for x in ast.walk(v)):
                    return False
        return True

    def walk(node: ast.AST, fn: Optional[ast.AST]):
        for child in ast.iter_child_nodes(node):
            # The scope is the outermost enclosing function: py2v emits a nested
            # function that uses `nonlocal` inline, sharing the outer one's types.
            is_fn = isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda))
            inner = child if is_fn and fn is None else fn
            if (isinstance(child, ast.If) and isinstance(child.test, ast.NamedExpr)
                    and isinstance(child.test.target, ast.Name)):
                child.test._hoist = check(child.test, fn)
            walk(child, inner)

    walk(tree, None)


def _detect_nesting_levels(tree: ast.Module):
    """Set `level` attribute on For, While, If nodes."""
    def _walk(node, level):
        if isinstance(node, (ast.For, ast.AsyncFor, ast.While, ast.If)):
            node._level = level
            for child in ast.iter_child_nodes(node):
                _walk(child, level + 1)
        elif isinstance(node, ast.FunctionDef) or isinstance(node, ast.AsyncFunctionDef):
            for child in ast.iter_child_nodes(node):
                _walk(child, 0)
        else:
            for child in ast.iter_child_nodes(node):
                _walk(child, level)
    _walk(tree, 0)


def _find_redefined_targets(tree: ast.Module) -> Dict[int, List[str]]:
    """
    For Assign nodes, identify targets that are being reassigned
    (previously defined in the same scope).
    Returns a mapping from node id to list of redefined target names.
    """
    result: Dict[int, List[str]] = {}

    def _scan_scope(body: List[ast.stmt]):
        defined: Set[str] = set()
        for node in body:
            if isinstance(node, ast.Assign):
                redefined = []
                new_names = []
                for target in node.targets:
                    for name in _extract_names(target):
                        if name in defined:
                            redefined.append(name)
                        new_names.append(name)
                if redefined:
                    result[id(node)] = redefined
                defined.update(new_names)
            elif isinstance(node, (ast.AnnAssign,)):
                if node.target:
                    defined.update(_extract_names(node.target))
            elif isinstance(node, ast.For):
                defined.update(_extract_names(node.target))
                _scan_scope(node.body)
                _scan_scope(node.orelse)
            elif isinstance(node, ast.While):
                _scan_scope(node.body)
                _scan_scope(node.orelse)
            elif isinstance(node, ast.If):
                _scan_scope(node.body)
                _scan_scope(node.orelse)
            elif isinstance(node, ast.Try):
                _scan_scope(node.body)
                for handler in node.handlers:
                    _scan_scope(handler.body)
                _scan_scope(node.orelse)
                _scan_scope(node.finalbody)
            elif isinstance(node, (ast.With, ast.AsyncWith)):
                _scan_scope(node.body)
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                # Start fresh scope for function body
                inner_defined: Set[str] = set()
                for arg in node.args.args:
                    inner_defined.add(arg.arg)
                _scan_func_scope(node.body, inner_defined)
            elif isinstance(node, ast.ClassDef):
                _scan_scope(node.body)

    def _scan_func_scope(body: List[ast.stmt], defined: Set[str]):
        for node in body:
            if isinstance(node, ast.Assign):
                redefined = []
                new_names = []
                for target in node.targets:
                    for name in _extract_names(target):
                        if name in defined:
                            redefined.append(name)
                        new_names.append(name)
                if redefined:
                    result[id(node)] = redefined
                defined.update(new_names)
            elif isinstance(node, (ast.AnnAssign,)):
                if node.target:
                    defined.update(_extract_names(node.target))
            elif isinstance(node, ast.For):
                defined.update(_extract_names(node.target))
                _scan_func_scope(node.body, defined)
                _scan_func_scope(node.orelse, defined)
            elif isinstance(node, ast.While):
                _scan_func_scope(node.body, defined)
                _scan_func_scope(node.orelse, defined)
            elif isinstance(node, ast.If):
                _scan_func_scope(node.body, defined)
                _scan_func_scope(node.orelse, defined)
            elif isinstance(node, ast.Try):
                _scan_func_scope(node.body, defined)
                for handler in node.handlers:
                    _scan_func_scope(handler.body, defined)
                _scan_func_scope(node.orelse, defined)
                _scan_func_scope(node.finalbody, defined)
            elif isinstance(node, (ast.With, ast.AsyncWith)):
                _scan_func_scope(node.body, defined)
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                inner_defined: Set[str] = set()
                for arg in node.args.args:
                    inner_defined.add(arg.arg)
                _scan_func_scope(node.body, inner_defined)

    _scan_scope(tree.body)
    return result


def _detect_decorator_kind(decorator_list) -> str:
    """Return the decorator kind for a function: staticmethod, classmethod, property,
    setter, or empty string."""
    for d in decorator_list:
        if isinstance(d, ast.Name):
            if d.id == "staticmethod":
                return "staticmethod"
            if d.id == "classmethod":
                return "classmethod"
            if d.id == "property":
                return "property"
        if isinstance(d, ast.Attribute):
            if d.attr == "setter":
                return "setter"
            if d.attr == "property":
                return "property"
    return ""


# Mapping of Python dunder names to their V operator/method equivalents.
_DUNDER_V_OP: Dict[str, str] = {
    "__add__": "+",
    "__sub__": "-",
    "__mul__": "*",
    "__truediv__": "/",
    "__floordiv__": "/",
    "__mod__": "%",
    "__eq__": "==",
    "__ne__": "!=",
    "__lt__": "<",
    "__le__": "<=",
    "__gt__": ">",
    "__ge__": ">=",
    "__str__": "str",
    "__repr__": "repr",
    "__len__": "len",
    "__getitem__": "index",
    "__setitem__": "index_set",
    "__contains__": "contains",
    "__neg__": "-",
    "__pos__": "+",
    "__invert__": "~",
}


def _dunder_to_v_op(name: str) -> str:
    """Return the V operator/method name for a Python dunder method, or ''."""
    return _DUNDER_V_OP.get(name, "")


# Python names that are renamed on every reference so the emitted V identifier is
# legal. Keys are Python dunder names, values are their V spelling.
_DUNDER_NAME_MAP: Dict[str, str] = {
    "__file__": "file___",
}


def _is_protocol_class(node: ast.ClassDef) -> bool:
    """Return True if the class directly inherits from Protocol."""
    for base in node.bases:
        if isinstance(base, ast.Name) and base.id == "Protocol":
            return True
        if isinstance(base, ast.Attribute) and base.attr == "Protocol":
            return True
    return False


def _extract_generic_type_params(node: ast.ClassDef) -> List[str]:
    """Return list of type parameter names from Generic[T, U, ...] base class."""
    for base in node.bases:
        # Generic[T] or typing.Generic[T]
        if isinstance(base, ast.Subscript):
            name = ""
            if isinstance(base.value, ast.Name):
                name = base.value.id
            elif isinstance(base.value, ast.Attribute):
                name = base.value.attr
            if name == "Generic":
                # slice is either a Name (single) or Tuple (multiple)
                s = base.slice
                if isinstance(s, ast.Name):
                    return [s.id]
                if isinstance(s, ast.Tuple):
                    return [e.id for e in s.elts if isinstance(e, ast.Name)]
    return []


def _is_v_generic_name(name: str) -> bool:
    return len(name) == 1 and "A" <= name <= "Z"


def _shorten_generic_names(tree: ast.Module) -> None:
    """Give long generic parameter names one capital letter each.

    V only accepts a single capital letter as a generic parameter, so
    `class Queue(Generic[QueueType])` cannot become `struct Queue[QueueType]`.
    A name in a `Generic[...]` base that is not one capital letter gets a
    letter that appears nowhere in the module as an identifier. Every
    `ast.Name` of that spelling is renamed, and so is a string annotation that
    is exactly the name.

    A name is left alone when the module also binds the spelling some other
    way (a parameter, a variable, a function, a class, an attribute, two
    imports, ...), since nothing else is rewritten. A module with more names
    than free letters keeps the remaining names as they are.
    """
    long_names: List[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            for name in _extract_generic_type_params(node):
                if not _is_v_generic_name(name) and name not in long_names:
                    long_names.append(name)
    if not long_names:
        return

    # The one binding a type parameter may have: `Name = TypeVar(...)`.
    typevar_targets = set()
    typevar_names = set()
    for node in ast.walk(tree):
        if (isinstance(node, ast.Assign) and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
                and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, (ast.Name, ast.Attribute))):
            func = node.value.func
            if (func.id if isinstance(func, ast.Name) else func.attr) == "TypeVar":
                typevar_targets.add(id(node.targets[0]))
                typevar_names.add(node.targets[0].id)

    # Every identifier the tree spells outside a Name being read, and every
    # Name, so a chosen letter is new and a name bound otherwise is known.
    taken = set()
    bound_otherwise = set()
    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Name):
            taken.add(node.id)
            if not isinstance(node.ctx, ast.Load) and id(node) not in typevar_targets:
                bound_otherwise.add(node.id)
            continue
        if isinstance(node, ast.Constant):
            continue
        for _, value in ast.iter_fields(node):
            for item in value if isinstance(value, list) else [value]:
                if isinstance(item, str):
                    taken.add(item)
                    # An imported type parameter is still only a type parameter,
                    # unless the spelling is imported twice or is also assigned
                    # a TypeVar here.
                    if not isinstance(node, ast.alias):
                        bound_otherwise.add(item)
        if isinstance(node, ast.alias):
            local = (node.asname or node.name).split(".")[0]
            if local in imported or local in typevar_names:
                bound_otherwise.add(local)
            imported.add(local)
            taken.add(local)

    letters = "TUVWXYZABCDEFGHIJKLMNOPQRS"
    renamed: Dict[str, str] = {}
    for name in long_names:
        if name in bound_otherwise:
            continue
        initial = name.lstrip("_")[:1].upper()
        for letter in initial + letters:
            if _is_v_generic_name(letter) and letter not in taken:
                renamed[name] = letter
                taken.add(letter)
                break
    if not renamed:
        return

    def rename_in_strings(part: Optional[ast.AST]) -> None:
        if part is None:
            return
        if isinstance(part, ast.Constant):
            # Only a string that is the name and nothing else: a longer
            # forward reference would need parsing.
            # Python spells identifiers in NFKC; a string keeps what was typed.
            if isinstance(part.value, str):
                spelled = unicodedata.normalize("NFKC", part.value)
                if spelled in renamed:
                    part.value = renamed[spelled]
            return
        if isinstance(part, ast.Subscript) and isinstance(part.value, (ast.Name, ast.Attribute)):
            base = part.value.id if isinstance(part.value, ast.Name) else part.value.attr
            # The strings of Literal[...] are values, and only the first item
            # of Annotated[...] is a type.
            if base == "Literal":
                return
            if base == "Annotated":
                if isinstance(part.slice, ast.Tuple) and part.slice.elts:
                    rename_in_strings(part.slice.elts[0])
                return
        for child in ast.iter_child_nodes(part):
            rename_in_strings(child)

    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and node.id in renamed:
            node.id = renamed[node.id]
        elif isinstance(node, ast.arg):
            rename_in_strings(node.annotation)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            rename_in_strings(node.returns)
        elif isinstance(node, ast.AnnAssign):
            rename_in_strings(node.annotation)


def _detect_class_methods(tree: ast.Module):
    """Mark methods inside classes with is_class_method and class_name."""
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            for item in node.body:
                if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    item._is_class_method = True
                    item._class_name = node.name



# Python bookkeeping class attributes. They describe the class itself and never
# become struct fields; the V backend filters them too, but keeping them out of
# the JSON makes the declarations readable.
_dunder_class_attrs = frozenset({
    "__slots__", "__doc__", "__module__", "__qualname__", "__dict__",
    "__weakref__", "__annotations__", "__dataclass_fields__",
})


def _class_field_types(tree: ast.AST, slots: Dict[str, ast.expr]
                       ) -> Dict[str, Dict[str, str]]:
    """Collect declarations and the types established by an initializer.

    The latter are needed before allocating the empty value passed to init.
    Only classes with a written, non-forwarding initializer acquire new field
    types. In particular, classes without an initializer keep their old layout.
    """
    result: Dict[str, Dict[str, str]] = {}
    classes = [node for node in ast.walk(tree) if isinstance(node, ast.ClassDef)]
    methods = {
        node.name: {method.name: _annotation_to_str(method.returns)
                    for method in node.body
                    if isinstance(method, (ast.FunctionDef, ast.AsyncFunctionDef))}
        for node in classes
    }
    for node in classes:
        declarations = _extract_class_declarations(node, slots)
        result[node.name] = {n: t for n, t in declarations.items() if t}
    # A local class may be declared after the initializer that constructs it.
    # This only adds known types; cycles without a known type stay unresolved.
    for _ in range(len(classes) + 1):
        changed = False
        for node in classes:
            declarations = _extract_class_declarations(node, slots)
            inferred = _initializer_field_types(node, declarations, result, methods)
            node._initializer_field_types = inferred
            known = {name: typ for name, typ in declarations.items() if typ}
            known.update(inferred)
            if result[node.name] != known:
                result[node.name] = known
                changed = True
        if not changed:
            break
    return result


def _forwarding_initializer(method: ast.FunctionDef) -> bool:
    """Recognize the old field-order path whose printed values must not change."""
    parameters = list(method.args.posonlyargs) + list(method.args.args)
    if (not parameters or parameters[0].arg != "self"
            or method.args.vararg or method.args.kwarg or method.args.kwonlyargs):
        return False
    assigned: List[str] = []
    for stmt in method.body:
        if isinstance(stmt, ast.Pass):
            continue
        if (isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant)
                and isinstance(stmt.value.value, str)):
            continue
        if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
            target, value = stmt.targets[0], stmt.value
        elif isinstance(stmt, ast.AnnAssign):
            target, value = stmt.target, stmt.value
        else:
            return False
        if (not isinstance(target, ast.Attribute)
                or not isinstance(target.value, ast.Name)
                or target.value.id != "self" or not isinstance(value, ast.Name)
                or target.attr != value.id):
            return False
        assigned.append(target.attr)
    return assigned == [arg.arg for arg in parameters[1:]]


def _initializer_field_types(node: ast.ClassDef, declarations: Dict[str, str],
                             classes: Dict[str, Dict[str, str]],
                             methods: Dict[str, Dict[str, str]]) -> Dict[str, str]:
    """Infer only fields written by init, without guessing an unknown value type.

    Explicit field annotations win. All assignments to an inferred field must
    agree; an unknown or conflicting assignment leaves that field unresolved.
    Forwarding initializers retain their old field types, including Any, so an
    existing successful program keeps the same observable representation.
    """
    initializer = next((method for method in node.body
                        if isinstance(method, (ast.FunctionDef, ast.AsyncFunctionDef))
                        and method.name == "__init__"), None)
    if initializer is None or _forwarding_initializer(initializer):
        node._unresolved_init_fields = []
        return {}
    fields = dict(_inherited_field_types(node.name, classes,
                                        [b.id for b in node.bases if isinstance(b, ast.Name)]))
    fields.update(classes.get(node.name, {}))
    candidates: Dict[str, Set[str]] = {}
    local_types = {arg.arg: _annotation_to_str(arg.annotation) or fields.get(arg.arg, "")
                   for arg in _all_args(initializer.args)}
    local_types["self"] = node.name

    def canonical(typ: str) -> str:
        return {"string": "str", "f64": "float"}.get(typ, typ)

    def value_type(value: Optional[ast.AST], local: Dict[str, str]) -> str:
        if isinstance(value, ast.Constant):
            return _infer_type_from_value(value)
        if isinstance(value, ast.Name):
            return canonical(local.get(value.id, ""))
        if isinstance(value, ast.Attribute):
            owner = value_type(value.value, local)
            owner_fields = fields if owner == node.name else classes.get(owner, {})
            return canonical(owner_fields.get(value.attr, ""))
        if isinstance(value, ast.Call):
            if isinstance(value.func, ast.Name) and value.func.id in classes:
                return value.func.id
            if isinstance(value.func, ast.Attribute):
                owner = value_type(value.func.value, local)
                typ = methods.get(owner, {}).get(value.func.attr, "")
                return canonical(typ) if typ not in ("None", "Any") else ""
        if isinstance(value, ast.BinOp):
            left, right = value_type(value.left, local), value_type(value.right, local)
            if (left in ("int", "float") and right in ("int", "float")
                    and isinstance(value.op, (ast.Add, ast.Sub, ast.Mult, ast.Div,
                                              ast.FloorDiv, ast.Mod))):
                return "float" if "float" in (left, right) or isinstance(value.op, ast.Div) else "int"
            if left == right == "str" and isinstance(value.op, ast.Add):
                return "str"
        if isinstance(value, ast.UnaryOp):
            if isinstance(value.op, ast.Not):
                return "bool"
            typ = value_type(value.operand, local)
            if typ in ("int", "float") and isinstance(value.op, (ast.UAdd, ast.USub)):
                return typ
        if isinstance(value, ast.Compare):
            return "bool"
        if isinstance(value, ast.IfExp):
            left, right = value_type(value.body, local), value_type(value.orelse, local)
            return left if left == right else ""
        return ""

    def scan(body: List[ast.stmt], local: Dict[str, str]) -> Dict[str, str]:
        for stmt in body:
            target, typ = None, ""
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
                target, typ = stmt.targets[0], value_type(stmt.value, local)
            elif isinstance(stmt, ast.AnnAssign):
                target, typ = stmt.target, _annotation_to_str(stmt.annotation)
            if isinstance(target, ast.Name):
                local[target.id] = typ
            elif (isinstance(target, ast.Attribute)
                  and isinstance(target.value, ast.Name) and target.value.id == "self"):
                candidates.setdefault(target.attr, set()).add(canonical(typ))
                if typ and not declarations.get(target.attr):
                    fields[target.attr] = typ
            elif isinstance(stmt, (ast.If, ast.For, ast.While, ast.Try, ast.With)):
                # Branch-local values cannot supply a type after the branch
                # unless every path agrees. Field assignments are collected
                # from every path, including exception handlers.
                branches = [scan(stmt.body, dict(local))]
                if hasattr(stmt, "orelse"):
                    branches.append(scan(stmt.orelse, dict(local)))
                if isinstance(stmt, ast.Try):
                    branches.extend(scan(handler.body, dict(local)) for handler in stmt.handlers)
                    branches.append(scan(stmt.finalbody, dict(local)))
                for name in set().union(*(set(branch) for branch in branches)):
                    types = {branch.get(name, "") for branch in branches}
                    local[name] = types.pop() if len(types) == 1 else ""
        return local

    scan(initializer.body, local_types)
    inferred = {name: next(iter(types)) for name, types in candidates.items()
                if not declarations.get(name) and len(types) == 1 and "" not in types
                and "Any" not in types}
    init_fields = dict(_self_attribute_targets(initializer.body))
    node._unresolved_init_fields = [name for name in init_fields
                                    if not declarations.get(name) and name not in inferred]
    return inferred


def _inherited_field_types(class_name: str, known: Dict[str, Dict[str, str]],
                           bases: List[str]) -> Dict[str, str]:
    """Field types a subclass inherits, nearest base first.

    A subclass constructor usually delegates straight to `super().__init__(...)`,
    so the parameters it accepts are the base's fields even though the subclass
    declares none of its own.
    """
    collected: Dict[str, str] = {}
    for base in bases:
        base_fields = known.get(base)
        if base_fields is None:
            continue
        for name, type_name in base_fields.items():
            collected.setdefault(name, type_name)
    return collected


def _all_args(arguments: ast.arguments) -> List[ast.arg]:
    """Every declared parameter, including positional-only and keyword-only."""
    collected: List[ast.arg] = []
    collected.extend(getattr(arguments, "posonlyargs", []) or [])
    collected.extend(arguments.args)
    collected.extend(arguments.kwonlyargs)
    return collected


def _collect_slots_by_class(tree: ast.AST) -> Dict[str, ast.expr]:
    """Map each class name in a module to its `__slots__` expression."""
    slots: Dict[str, ast.expr] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.ClassDef):
            continue
        for item in node.body:
            if (isinstance(item, ast.Assign)
                    and len(item.targets) == 1
                    and isinstance(item.targets[0], ast.Name)
                    and item.targets[0].id == "__slots__"):
                slots[node.name] = item.value
    return slots


def _const_string_sequence(node: ast.expr,
                           slots: Dict[str, ast.expr]) -> Optional[List[str]]:
    """Fold a `__slots__` expression into the attribute names it lists.

    Slots are usually a literal tuple, but they are routinely assembled from a
    base class, so concatenation and a bare name that refers to another class's
    slots are folded too. Anything that needs real evaluation returns None,
    which simply means the class falls back to the other field sources.
    """
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return [node.value]
    if isinstance(node, (ast.Tuple, ast.List)):
        names: List[str] = []
        for element in node.elts:
            folded = _const_string_sequence(element, slots)
            if folded is None:
                return None
            names.extend(folded)
        return names
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        left = _const_string_sequence(node.left, slots)
        right = _const_string_sequence(node.right, slots)
        if left is None or right is None:
            return None
        return left + right
    if isinstance(node, ast.Name):
        referenced = slots.get(node.id)
        if referenced is None:
            return None
        return _const_string_sequence(referenced, slots)
    return None


def _self_attribute_targets(body: List[ast.stmt]) -> List[Tuple[str, str]]:
    """Collect `self.x` assignments in a method body, with a type hint if any.

    Python lets a method assign to any attribute at any point, including inside
    a branch, so the whole body is walked rather than only its top level.
    """
    found: List[Tuple[str, str]] = []
    for node in ast.walk(ast.Module(body=list(body), type_ignores=[])):
        target = None
        annotation = None
        if isinstance(node, ast.AnnAssign):
            target = node.target
            annotation = _annotation_to_str(node.annotation)
        elif isinstance(node, ast.Assign) and len(node.targets) == 1:
            target = node.targets[0]
        if (target is None
                or not isinstance(target, ast.Attribute)
                or not isinstance(target.value, ast.Name)
                or target.value.id != "self"):
            continue
        found.append((target.attr, annotation or ""))
    return found


def _extract_class_declarations(node: ast.ClassDef,
                                slots: Optional[Dict[str, ast.expr]] = None
                                ) -> Dict[str, str]:
    """Extract field declarations from a class body.

    Fields come from four places, in the order a V struct should declare them:
    annotated and plain class-level names, the `__slots__` tuple, and `self.x`
    assignments. Every method is searched for the latter, not just `__init__`,
    because plenty of classes only ever assign an attribute from a helper or a
    lifecycle method, and those fields still have to exist in the struct.
    """
    decls: Dict[str, str] = {}
    slots = slots or {}

    def declare(name: str, type_name: str) -> None:
        if not name or name in _dunder_class_attrs:
            return
        if name not in decls:
            decls[name] = type_name
        elif not decls[name] and type_name:
            # A name first seen in `__slots__` is untyped there; the annotated
            # assignment that fills it later carries the real type.
            decls[name] = type_name

    for item in node.body:
        if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name):
            declare(item.target.id, _annotation_to_str(item.annotation))
    for item in node.body:
        # Class-level bare assignment: FIELD = value
        if (isinstance(item, ast.Assign)
                and len(item.targets) == 1
                and isinstance(item.targets[0], ast.Name)
                and item.targets[0].id != "__slots__"):
            declare(item.targets[0].id, _infer_type_from_value(item.value))

    declared_slots = slots.get(node.name)
    if declared_slots is not None:
        for slot_name in _const_string_sequence(declared_slots, slots) or []:
            declare(slot_name, "")

    # `__init__` first, so that the fields it establishes lead the struct, then
    # every other method in declaration order.
    methods = [item for item in node.body
               if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))]
    for method in methods:
        if method.name != "__init__":
            continue
        for name, type_name in _self_attribute_targets(method.body):
            declare(name, type_name)
    for method in methods:
        if method.name == "__init__":
            continue
        for name, type_name in _self_attribute_targets(method.body):
            declare(name, type_name)
    return decls


def _extract_class_defaults(node: ast.ClassDef, mutable_vars, redefined,
                            ctx: Optional["AnalysisContext"] = None) -> Dict[str, Any]:
    """Extract default values for class-level fields."""
    if ctx is None:
        ctx = AnalysisContext.empty()
    defaults = {}
    for item in node.body:
        if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name):
            if item.value is not None:
                defaults[item.target.id] = _node_to_dict(item.value, mutable_vars, redefined, ctx)
        elif isinstance(item, ast.Assign):
            if (len(item.targets) == 1
                    and isinstance(item.targets[0], ast.Name)):
                defaults[item.targets[0].id] = _node_to_dict(item.value, mutable_vars, redefined, ctx)
    return defaults


def _annotation_to_str(node: Optional[ast.AST]) -> str:
    if node is None:
        return ""
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Constant):
        return str(node.value)
    if isinstance(node, ast.Subscript):
        return f"{_annotation_to_str(node.value)}[{_annotation_to_str(node.slice)}]"
    if isinstance(node, ast.Attribute):
        return f"{_annotation_to_str(node.value)}.{node.attr}"
    if isinstance(node, ast.Tuple):
        return ", ".join(_annotation_to_str(e) for e in node.elts)
    # PEP 604: X | Y union types (Python 3.10+)
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.BitOr):
        left = _annotation_to_str(node.left)
        right = _annotation_to_str(node.right)
        # X | None  ->  Optional[X]
        if right == "None":
            return f"Optional[{left}]"
        # None | X  ->  Optional[X]
        if left == "None":
            return f"Optional[{right}]"
        # General union: X | Y  ->  just use left for now
        return left
    return ""


def _unparse_expr(node: ast.AST) -> str:
    """Render annotation-like syntax on Python 3.8, which lacks ast.unparse."""
    unparse = getattr(ast, "unparse", None)
    if unparse is not None:
        return unparse(node)
    if isinstance(node, ast.Index):
        return _unparse_expr(node.value)
    if isinstance(node, ast.Subscript):
        return f"{_unparse_expr(node.value)}[{_unparse_expr(node.slice)}]"
    if isinstance(node, ast.Tuple):
        return ", ".join(_unparse_expr(e) for e in node.elts)
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.BitOr):
        return f"{_unparse_expr(node.left)} | {_unparse_expr(node.right)}"
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return repr(node.value)
    return _annotation_to_str(node)


# ---------------------------------------------------------------------------
# AST to JSON serializer
# ---------------------------------------------------------------------------

def _node_to_dict(node: ast.AST, mutable_vars: Set[str],
                  redefined: Dict[int, List[str]],
                  ctx: Optional[AnalysisContext] = None) -> Dict[str, Any]:
    """Convert an AST node to a JSON-serializable dict.

    ``ctx`` carries per-file annotation maps (var_annotations and
    func_ret_annotations).  It is never None inside a call – callers that
    do not have a context yet should pass ``AnalysisContext.empty()``.
    """
    if ctx is None:
        ctx = AnalysisContext.empty()
    # Convenience aliases used throughout this function
    var_annotations = ctx.var_annotations
    result: Dict[str, Any] = {}
    result["node_type"] = type(node).__name__

    # Location info
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(node, attr):
            val = getattr(node, attr)
            if val is not None:
                result[attr] = val

    # Handle specific node types
    if isinstance(node, ast.Module):
        result["condition_walrus_names"] = getattr(node, "_condition_walrus_names", [])
        result["module_consts"] = getattr(node, "_module_consts", [])
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        docstring = _extract_docstring(node)
        if docstring:
            result["docstring_comment"] = docstring

    elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        result["name"] = node.name
        result["condition_walrus_names"] = getattr(node, "_condition_walrus_names", [])

        # Compute mutable vars within this function FIRST
        tracker = ScopeTracker()
        tracker.visit(node)
        func_mutable = tracker.mutable | ctx.rebound_parameters(node)
        result["mutable_vars"] = sorted(func_mutable)

        # Build a local var_annotation map including parameter annotations so
        # Name nodes inside the function body can get v_annotation hints.
        # A name this function binds itself is not the module variable of the same name.
        owned = ctx.owned_names(node)
        local_ann = {k: v for k, v in var_annotations.items() if k not in owned}
        # Positional and keyword args
        for a in list(node.args.posonlyargs) + list(node.args.args) + list(node.args.kwonlyargs):
            if a.annotation is not None and isinstance(a, ast.arg):
                name = a.arg
                ann_str = _annotation_to_str(a.annotation)
                if ann_str == 'str':
                    ann_str = 'string'
                local_ann[name] = ann_str
        # vararg/kwarg
        if node.args.vararg is not None:
            va = node.args.vararg
            if va.annotation is not None:
                ann_str = _annotation_to_str(va.annotation)
                if ann_str == 'str':
                    ann_str = 'string'
                local_ann[va.arg] = ann_str
        if node.args.kwarg is not None:
            ka = node.args.kwarg
            if ka.annotation is not None:
                ann_str = _annotation_to_str(ka.annotation)
                if ann_str == 'str':
                    ann_str = 'string'
                local_ann[ka.arg] = ann_str

        # Collect simple annotated assignments and simple constant assignments
        # at the top-level of the function body (conservative). This lets
        # local variables with obvious types provide v_annotation hints to
        # Name nodes inside the function body.
        for stmt in node.body:
            if isinstance(stmt, ast.AnnAssign):
                if isinstance(stmt.target, ast.Name) and stmt.annotation is not None:
                    tgt = stmt.target.id
                    tstr = _annotation_to_str(stmt.annotation)
                    if tstr == 'str':
                        tstr = 'string'
                    if tstr:
                        local_ann[tgt] = tstr
            elif isinstance(stmt, ast.Assign):
                # Simple assignment of constant literal: x = 1
                if len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
                    tgt = stmt.targets[0].id
                    typ = _infer_type_from_value(stmt.value)
                    if typ == 'str':
                        local_ann[tgt] = 'string'
                    elif typ != '':
                        local_ann[tgt] = typ

        for name, typ in getattr(node, "_condition_walrus_hints", {}).items():
            # This local shadows a module name just as a plain assignment does.
            # The planner excludes parameters and every other local binding.
            local_ann[name] = _normalize_inferred_type_name(typ)

        # `def __init__(self, x): self.x = x` against an annotated field gives
        # the parameter the field's type. Without it the field is typed but the
        # assignment that fills it is not, which V rejects.
        for arg in _all_args(node.args):
            if arg.annotation is not None or arg.arg == "self":
                continue
            field_type = ctx.field_types.get(arg.arg)
            if field_type and field_type not in ("", "Any"):
                local_ann[arg.arg] = field_type

        # Serialised after local_ann so an inferred parameter type can ride along.
        result["args"] = _arguments_to_dict(node.args, func_mutable, local_ann)

        result["body"] = [_node_to_dict(n, func_mutable, redefined,
                                        AnalysisContext(local_ann, ctx.func_ret_annotations,
                                                        ctx.slots_by_class, ctx.field_types,
                                                        table=ctx.table, facts=ctx.facts)) for n in node.body]
        result["decorator_list"] = [_node_to_dict(d, mutable_vars, redefined, ctx) for d in node.decorator_list]
        result["returns"] = _node_to_dict(node.returns, mutable_vars, redefined, ctx) if node.returns else None
        result["type_comment"] = getattr(node, "type_comment", None)
        result["is_void"] = _is_void_function(node)
        if getattr(node, "_raises", False):
            result["raises"] = True
        result["is_generator"] = _is_generator(node)
        result["is_class_method"] = getattr(node, "_is_class_method", False)
        result["class_name"] = getattr(node, "_class_name", "")
        result["decorator_kind"] = _detect_decorator_kind(node.decorator_list)
        result["dunder_op"] = _dunder_to_v_op(node.name)
        inferred_ret = _infer_return_type(node)
        if inferred_ret:
            result["v_annotation"] = inferred_ret

    elif isinstance(node, ast.ClassDef):
        declarations = _extract_class_declarations(node, ctx.slots_by_class)
        declarations.update(getattr(node, "_initializer_field_types", {}))
        own_types = {name: typ for name, typ in declarations.items() if typ}
        base_names = [b.id for b in node.bases if isinstance(b, ast.Name)]
        field_types = dict(_inherited_field_types(node.name, ctx.class_field_types,
                                                  base_names))
        field_types.update(own_types)
        body_ctx = AnalysisContext(ctx.var_annotations, ctx.func_ret_annotations,
                                   ctx.slots_by_class, field_types, table=ctx.table, facts=ctx.facts)
        result["name"] = node.name
        result["bases"] = [_node_to_dict(b, mutable_vars, redefined, ctx) for b in node.bases]
        result["keywords"] = [_keyword_to_dict(kw, mutable_vars, redefined, ctx) for kw in node.keywords]
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, body_ctx) for n in node.body]
        result["decorator_list"] = [_node_to_dict(d, mutable_vars, redefined, ctx) for d in node.decorator_list]
        # Lists of [name, value] pairs, not objects keyed by the field name: V's json2 reads a
        # "_type" key as a sum type tag, so a field named `_type` would make the file undecodable.
        result["declarations"] = [[name, typ] for name, typ in declarations.items()]
        result["class_defaults"] = [
            [name, default] for name, default
            in _extract_class_defaults(node, mutable_vars, redefined, ctx).items()]
        result["unresolved_init_fields"] = getattr(node, "_unresolved_init_fields", [])
        result["is_protocol"] = _is_protocol_class(node)
        result["type_params"] = _extract_generic_type_params(node)
        # Extract class-level docstring
        if (node.body
                and isinstance(node.body[0], ast.Expr)
                and isinstance(node.body[0].value, ast.Constant)
                and isinstance(node.body[0].value.value, str)):
            result["docstring_comment"] = node.body[0].value.value

    elif isinstance(node, ast.Return):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx) if node.value else None

    elif isinstance(node, ast.Delete):
        result["targets"] = [_node_to_dict(t, mutable_vars, redefined, ctx) for t in node.targets]

    elif isinstance(node, ast.Assign):
        result["targets"] = [_node_to_dict(t, mutable_vars, redefined, ctx) for t in node.targets]
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["type_comment"] = getattr(node, "type_comment", None)
        redef = redefined.get(id(node), [])
        if redef:
            result["redefined_targets"] = redef
        # Mark TypeVar assignments so the backend can skip them
        if (isinstance(node.value, ast.Call)
                and isinstance(node.value.func, (ast.Name, ast.Attribute))):
            fname = (node.value.func.id if isinstance(node.value.func, ast.Name)
                     else node.value.func.attr)
            if fname == "TypeVar":
                result["is_typevar_assign"] = True
        # Literal[...] subscript type aliases are pure type-system metadata.
        if (isinstance(node.value, ast.Subscript)
                and isinstance(node.value.value, (ast.Name, ast.Attribute))):
            sname = (node.value.value.id if isinstance(node.value.value, ast.Name)
                     else node.value.value.attr)
            if sname == "Literal":
                result["is_typevar_assign"] = True
                # Extract the literal values so the backend can emit a const block.
                slice_node = node.value.slice
                raw_elts = []
                if isinstance(slice_node, ast.Tuple):
                    raw_elts = slice_node.elts
                else:
                    raw_elts = [slice_node]
                lit_values = []
                for elt in raw_elts:
                    if isinstance(elt, ast.Constant):
                        lit_values.append(elt.value)
                if lit_values:
                    result["literal_values"] = lit_values
                    # name is the first target identifier
                    if node.targets and isinstance(node.targets[0], ast.Name):
                        result["literal_name"] = node.targets[0].id

    elif isinstance(node, ast.AugAssign):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["op"] = {"node_type": type(node.op).__name__}
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.AnnAssign):
        native_map = ctx.native_map_annotation(node)
        annotation = _annotation_node(native_map, node.annotation) if native_map else node.annotation
        if native_map:
            ctx.var_annotations[node.target.id] = native_map
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["annotation"] = _node_to_dict(annotation, mutable_vars, redefined, ctx)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx) if node.value else None
        result["simple"] = node.simple

    elif isinstance(node, (ast.For, ast.AsyncFor)):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["iter"] = _node_to_dict(node.iter, mutable_vars, redefined, ctx)
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.orelse]
        result["type_comment"] = getattr(node, "type_comment", None)
        result["level"] = getattr(node, "_level", 0)

    elif isinstance(node, ast.While):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined, ctx)
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.orelse]
        result["level"] = getattr(node, "_level", 0)

    elif isinstance(node, ast.If):
        result["lower_condition_walrus"] = getattr(node, "_lower_condition_walrus", False)
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined, ctx)
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.orelse]
        result["level"] = getattr(node, "_level", 0)

    elif isinstance(node, (ast.With, ast.AsyncWith)):
        result["items"] = [_withitem_to_dict(item, mutable_vars, redefined, ctx) for item in node.items]
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["type_comment"] = getattr(node, "type_comment", None)

    elif isinstance(node, ast.Raise):
        result["exc"] = _node_to_dict(node.exc, mutable_vars, redefined, ctx) if node.exc else None
        result["cause"] = _node_to_dict(node.cause, mutable_vars, redefined, ctx) if node.cause else None
        if getattr(node, "_mode", ""):
            result["mode"] = node._mode
            result["guard"] = getattr(node, "_guard", 0)
            result["bases"] = getattr(node, "_bases", None) or []

    elif hasattr(ast, "TryStar") and isinstance(node, ast.TryStar):
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["handlers"] = [_handler_to_dict(h, mutable_vars, redefined, ctx) for h in node.handlers]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.orelse]
        result["finalbody"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.finalbody]

    elif isinstance(node, ast.Try):
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["handlers"] = [_handler_to_dict(h, mutable_vars, redefined, ctx) for h in node.handlers]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.orelse]
        result["finalbody"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.finalbody]
        if getattr(node, "_guard", 0):
            result["guard"] = node._guard

    elif isinstance(node, ast.Assert):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined, ctx)
        result["msg"] = _node_to_dict(node.msg, mutable_vars, redefined, ctx) if node.msg else None

    elif isinstance(node, ast.Import):
        result["names"] = [_alias_to_dict(a) for a in node.names]

    elif isinstance(node, ast.ImportFrom):
        result["module"] = node.module
        result["names"] = [_alias_to_dict(a) for a in node.names]
        result["level"] = node.level

    elif isinstance(node, ast.Global):
        result["names"] = node.names

    elif isinstance(node, ast.Nonlocal):
        result["names"] = node.names

    elif hasattr(ast, "TypeAlias") and isinstance(node, ast.TypeAlias):
        result["name"] = _node_to_dict(node.name, mutable_vars, redefined, ctx)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    elif hasattr(ast, "Match") and isinstance(node, ast.Match):
        result["subject"] = _node_to_dict(node.subject, mutable_vars, redefined, ctx)
        result["cases"] = [
            _match_case_to_dict(c, mutable_vars, redefined, ctx) for c in node.cases
        ]

    elif isinstance(node, ast.Expr):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    # Expressions
    elif isinstance(node, ast.BoolOp):
        result["op"] = {"node_type": type(node.op).__name__}
        result["values"] = [_node_to_dict(v, mutable_vars, redefined, ctx) for v in node.values]

    elif isinstance(node, ast.NamedExpr):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["hoist"] = getattr(node, "_hoist", False)

    elif isinstance(node, ast.BinOp):
        result["left"] = _node_to_dict(node.left, mutable_vars, redefined, ctx)
        result["op"] = {"node_type": type(node.op).__name__}
        result["right"] = _node_to_dict(node.right, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.UnaryOp):
        result["op"] = {"node_type": type(node.op).__name__}
        result["operand"] = _node_to_dict(node.operand, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.Lambda):
        result["args"] = _arguments_to_dict(node.args, mutable_vars)
        result["body"] = _node_to_dict(node.body, mutable_vars, redefined, ctx)
        # Attempt to infer simple return type for lambda bodies (constants/straightforward
        # expressions) and mark lambdas as inlinable when the body is a single simple
        # expression. This helps the backend emit typed closures and inline bodies.
        try:
            ret_type = _infer_type_from_value(node.body)
        except Exception:
            ret_type = ""
        if ret_type:
            result["v_annotation"] = ret_type
        # Mark simple lambda bodies as inlinable so backends can prefer AST-level
        # inlining instead of fragile textual substitution.
        if isinstance(node.body, (ast.Constant, ast.Name, ast.Attribute,
                                  ast.Call, ast.BinOp, ast.Subscript)):
            result["inlinable"] = True
            # Provide a source fallback when available (Python 3.9+ ast.unparse)
            if hasattr(ast, "unparse"):
                try:
                    result["body_src"] = _unparse_expr(node.body)
                except Exception:
                    pass

    elif isinstance(node, ast.IfExp):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined, ctx)
        result["body"] = _node_to_dict(node.body, mutable_vars, redefined, ctx)
        result["orelse"] = _node_to_dict(node.orelse, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.Dict):
        result["keys"] = [_node_to_dict(k, mutable_vars, redefined, ctx) if k else None for k in node.keys]
        result["values"] = [_node_to_dict(v, mutable_vars, redefined, ctx) for v in node.values]

    elif isinstance(node, ast.Set):
        result["elts"] = [_node_to_dict(e, mutable_vars, redefined, ctx) for e in node.elts]

    elif isinstance(node, (ast.ListComp, ast.SetComp, ast.GeneratorExp)):
        result["elt"] = _node_to_dict(node.elt, mutable_vars, redefined, ctx)
        result["generators"] = [_comprehension_to_dict(g, mutable_vars, redefined, ctx) for g in node.generators]

    elif isinstance(node, ast.DictComp):
        result["key"] = _node_to_dict(node.key, mutable_vars, redefined, ctx)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["generators"] = [_comprehension_to_dict(g, mutable_vars, redefined, ctx) for g in node.generators]

    elif isinstance(node, ast.Await):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.Yield):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx) if node.value else None

    elif isinstance(node, ast.YieldFrom):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.Compare):
        result["left"] = _node_to_dict(node.left, mutable_vars, redefined, ctx)
        result["ops"] = [{"node_type": type(op).__name__} for op in node.ops]
        result["comparators"] = [_node_to_dict(c, mutable_vars, redefined, ctx) for c in node.comparators]

    elif isinstance(node, ast.Call):
        result["func"] = _node_to_dict(node.func, mutable_vars, redefined, ctx)
        result["args"] = [_node_to_dict(a, mutable_vars, redefined, ctx) for a in node.args]
        result["keywords"] = [_keyword_to_dict(kw, mutable_vars, redefined, ctx) for kw in node.keywords]
        if getattr(node, "_subject_class", ""):
            result["subject_class"] = node._subject_class
        if getattr(node, "_api", ""):
            result["api"] = node._api
        if getattr(node, "_propagate", False):
            result["propagate"] = True
        if getattr(node, "_guard", 0):
            result["guard"] = node._guard
        # Attach v_annotation for calls when the callee is a top-level function
        # with an explicit return annotation discovered during pre-scan.
        if isinstance(node.func, ast.Name):
            fname = node.func.id
            if fname in ctx.func_ret_annotations:
                result["v_annotation"] = ctx.func_ret_annotations[fname]

    elif isinstance(node, ast.FormattedValue):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["conversion"] = node.conversion
        result["format_spec"] = _node_to_dict(node.format_spec, mutable_vars, redefined, ctx) if node.format_spec else None

    elif isinstance(node, ast.JoinedStr):
        result["values"] = [_node_to_dict(v, mutable_vars, redefined, ctx) for v in node.values]

    elif isinstance(node, ast.Constant):
        result["value"] = _constant_value(node.value)
        result["kind"] = node.kind
        # Provide v_annotation for primitive literal types to help downstream
        # type-aware transpilation in the backend.
        if isinstance(node.value, bool):
            result["v_annotation"] = "bool"
        elif isinstance(node.value, int):
            result["v_annotation"] = "int"
        elif isinstance(node.value, float):
            result["v_annotation"] = "float"
        elif isinstance(node.value, str):
            result["v_annotation"] = "string"
        elif isinstance(node.value, bytes):
            # Represent raw bytes literals as a bytes annotation; backend may map
            # this to a V `[]u8` literal.
            result["v_annotation"] = "bytes"

    elif isinstance(node, ast.Attribute):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["attr"] = node.attr
        result["ctx"] = {"node_type": type(node.ctx).__name__}
        if getattr(node, "_api", ""):
            result["api"] = node._api

    elif isinstance(node, ast.Subscript):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["slice"] = _node_to_dict(node.slice, mutable_vars, redefined, ctx)
        result["ctx"] = {"node_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Starred):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["ctx"] = {"node_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Name):
        # Python module dunders with a direct V spelling are renamed here so
        # that every reference site agrees. A read of `__file__` is V's `@FILE`,
        # the path of the source file as a compile-time string.
        if node.id == "__file__" and isinstance(node.ctx, ast.Load):
            result["id"] = "@FILE"
        else:
            result["id"] = _DUNDER_NAME_MAP.get(node.id, node.id)
        result["ctx"] = {"node_type": type(node.ctx).__name__}
        result["is_mutable"] = node.id in mutable_vars
        if getattr(node, "_math_member", ""):
            result["math_member"] = node._math_member
        if getattr(node, "_api", ""):
            result["api"] = node._api
        # Attach simple v_annotation if we discovered one during pre-scan
        if node.id in var_annotations:
            result["v_annotation"] = var_annotations[node.id]

    elif isinstance(node, (ast.List, ast.Tuple)):
        result["elts"] = [_node_to_dict(e, mutable_vars, redefined, ctx) for e in node.elts]
        result["ctx"] = {"node_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Slice):
        result["lower"] = _node_to_dict(node.lower, mutable_vars, redefined, ctx) if node.lower else None
        result["upper"] = _node_to_dict(node.upper, mutable_vars, redefined, ctx) if node.upper else None
        result["step"] = _node_to_dict(node.step, mutable_vars, redefined, ctx) if node.step else None

    # The backend reads `v_annotation` on an expression as its type. Where the passes above
    # did not set one, the inferred scalar type fills it in.
    if isinstance(node, ast.expr) and "v_annotation" not in result:
        scalar = getattr(node, "_runtime_annotation", "") or ctx.scalar_annotation(node)
        if scalar:
            result["v_annotation"] = scalar

    return result


def _constant_value(value: Any) -> Any:
    """Convert a Python constant to JSON-safe representation."""
    if value is None:
        return None
    if value is True:
        return True
    if value is False:
        return False
    if isinstance(value, (int, float, str)):
        return value
    if isinstance(value, bytes):
        return {"node_type": "bytes", "value": list(value)}
    if value is Ellipsis:
        return {"node_type": "Ellipsis"}
    if isinstance(value, complex):
        return {"node_type": "complex", "real": value.real, "imag": value.imag}
    return str(value)


def _gather_var_annotations(tree: ast.Module) -> Dict[str, str]:
    """Collect simple variable annotations from module-level AnnAssign and
    simple Assign-to-constant statements. Returns a mapping name -> v_annotation
    (e.g., 'x' -> 'int' or 'string'). This is intentionally conservative.
    """
    ann: Dict[str, str] = {}
    for node in tree.body:
        if isinstance(node, ast.AnnAssign):
            # Only consider simple name targets
            if isinstance(node.target, ast.Name) and node.annotation is not None:
                ann_name = node.target.id
                type_str = _annotation_to_str(node.annotation)
                if type_str:
                    # Normalize basic Python types to the frontend v_annotation
                    if type_str == 'str':
                        ann[ann_name] = 'string'
                    else:
                        ann[ann_name] = type_str
        elif isinstance(node, ast.Assign):
            # Simple assignment of constant literal: x = 1
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                tgt = node.targets[0].id
                typ = _infer_type_from_value(node.value)
                if typ == 'str':
                    ann[tgt] = 'string'
                elif typ != '':
                    ann[tgt] = typ
        elif (isinstance(node, ast.If) and isinstance(node.test, ast.NamedExpr)
              and getattr(node.test, "_hoist", False)):
            # A hoisted walrus binds its name like `x = value`.
            typ = _infer_type_from_value(node.test.value)
            if typ == 'str':
                ann[node.test.target.id] = 'string'
            elif typ != '':
                ann[node.test.target.id] = typ
    return ann


def _gather_func_return_annotations(tree: ast.Module) -> Dict[str, str]:
    """Collect explicit return annotations from top-level FunctionDef nodes.
    Returns mapping function_name -> v_annotation (string)
    """
    ret: Dict[str, str] = {}
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.returns is not None:
                rt = _annotation_to_str(node.returns)
                if rt == 'str':
                    rt = 'string'
                if rt:
                    ret[node.name] = rt
    return ret


def _arguments_to_dict(args: ast.arguments, mutable_vars: Set[str],
                      hints: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    hints = hints or {}
    return {
        "node_type": "arguments",
        "posonlyargs": [_arg_to_dict(a, mutable_vars, hints) for a in args.posonlyargs],
        "args": [_arg_to_dict(a, mutable_vars, hints) for a in args.args],
        "vararg": _arg_to_dict(args.vararg, mutable_vars, hints) if args.vararg else None,
        "kwonlyargs": [_arg_to_dict(a, mutable_vars, hints) for a in args.kwonlyargs],
        "kw_defaults": [_node_to_dict(d, mutable_vars, {}, AnalysisContext.empty()) if d else None for d in args.kw_defaults],
        "kwarg": _arg_to_dict(args.kwarg, mutable_vars, hints) if args.kwarg else None,
        "defaults": [_node_to_dict(d, mutable_vars, {}, AnalysisContext.empty()) for d in args.defaults],
    }


def _arg_to_dict(arg: ast.arg, mutable_vars: Set[str],
                 hints: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    hints = hints or {}
    result = {
        "node_type": "arg",
        "arg": arg.arg,
        "annotation": _node_to_dict(arg.annotation, mutable_vars, {}, AnalysisContext.empty()) if arg.annotation else None,
        "type_comment": getattr(arg, "type_comment", None),
        "is_mutable": arg.arg in mutable_vars,
    }
    # An inferred type for a parameter that carries no annotation of its own, so
    # that the declaration and its uses agree on the V type.
    if arg.annotation is None and hints.get(arg.arg):
        result["v_annotation"] = hints[arg.arg]
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(arg, attr):
            val = getattr(arg, attr)
            if val is not None:
                result[attr] = val
    return result


def _keyword_to_dict(kw: ast.keyword, mutable_vars: Set[str],
                     redefined: Dict[int, List[str]],
                     ctx: Optional[AnalysisContext] = None) -> Dict[str, Any]:
    if ctx is None:
        ctx = AnalysisContext.empty()
    result = {
        "node_type": "keyword",
        "arg": kw.arg,
        "value": _node_to_dict(kw.value, mutable_vars, redefined, ctx),
    }
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(kw, attr):
            val = getattr(kw, attr)
            if val is not None:
                result[attr] = val
    return result


def _alias_to_dict(alias: ast.alias) -> Dict[str, Any]:
    result = {
        "node_type": "alias",
        "name": alias.name,
        "asname": alias.asname,
    }
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(alias, attr):
            val = getattr(alias, attr)
            if val is not None:
                result[attr] = val
    return result


def _handler_to_dict(handler: ast.ExceptHandler, mutable_vars: Set[str],
                     redefined: Dict[int, List[str]],
                     ctx: Optional[AnalysisContext] = None) -> Dict[str, Any]:
    if ctx is None:
        ctx = AnalysisContext.empty()
    result = {
        "node_type": "ExceptHandler",
        "type": _node_to_dict(handler.type, mutable_vars, redefined, ctx) if handler.type else None,
        "name": handler.name,
        "body": [_node_to_dict(n, mutable_vars, redefined, ctx) for n in handler.body],
    }
    if getattr(handler, "_classes", None) is not None:
        result["classes"] = handler._classes
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(handler, attr):
            val = getattr(handler, attr)
            if val is not None:
                result[attr] = val
    return result


def _withitem_to_dict(item: ast.withitem, mutable_vars: Set[str],
                      redefined: Dict[int, List[str]],
                      ctx: Optional[AnalysisContext] = None) -> Dict[str, Any]:
    if ctx is None:
        ctx = AnalysisContext.empty()
    return {
        "node_type": "withitem",
        "context_expr": _node_to_dict(item.context_expr, mutable_vars, redefined, ctx),
        "optional_vars": _node_to_dict(item.optional_vars, mutable_vars, redefined, ctx) if item.optional_vars else None,
    }


def _comprehension_to_dict(comp: ast.comprehension, mutable_vars: Set[str],
                           redefined: Dict[int, List[str]],
                           ctx: Optional[AnalysisContext] = None) -> Dict[str, Any]:
    if ctx is None:
        ctx = AnalysisContext.empty()
    return {
        "node_type": "comprehension",
        "target": _node_to_dict(comp.target, mutable_vars, redefined, ctx),
        "iter": _node_to_dict(comp.iter, mutable_vars, redefined, ctx),
        "ifs": [_node_to_dict(i, mutable_vars, redefined, ctx) for i in comp.ifs],
        "is_async": bool(comp.is_async),
    }


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def _mutating_method_names(tree: ast.Module) -> Set[str]:
    """Names of the methods that change their object: they store into `self` (an attribute,
    an element, a mutating list call) or call such a method on `self`."""
    methods = [fn for cls in ast.walk(tree) if isinstance(cls, ast.ClassDef)
               for fn in cls.body if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef))
               and fn.args.args and fn.args.args[0].arg == "self" and fn.name != "__init__"]
    names: Set[str] = set()
    ScopeTracker.mutating_methods = set()
    while True:
        found = set()
        for fn in methods:
            tracker = ScopeTracker()
            tracker.visit(fn)
            if "self" in tracker.mutable:
                found.add(fn.name)
        if found == names:
            return names
        names = found
        ScopeTracker.mutating_methods = names


def _mutating_function_params(tree: ast.Module,
                              table: Optional[symbols.SymbolTable]) -> Dict[str, Set[int]]:
    """For each function outside a class: the positions of the parameters the backend
    declares `mut`, which are those the body changes, except a rebound number, string or
    bool (copied inside the function). Calls between such functions carry the fact on."""
    class_level = {id(fn) for cls in ast.walk(tree) if isinstance(cls, ast.ClassDef)
                   for fn in cls.body}
    functions = [fn for fn in ast.walk(tree)
                 if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef))
                 and id(fn) not in class_level]
    ctx = AnalysisContext(table=table)
    found: Dict[str, Set[int]] = {}
    ScopeTracker.mutating_functions = {}
    while True:
        current: Dict[str, Set[int]] = {}
        for fn in functions:
            tracker = ScopeTracker()
            tracker.visit(fn)
            changed = tracker.mutable | ctx.rebound_parameters(fn)
            for index, arg in enumerate(fn.args.args):
                value_type = (isinstance(arg.annotation, ast.Name)
                              and arg.annotation.id in ("int", "float", "str", "bool"))
                if arg.arg in changed and not value_type:
                    current.setdefault(fn.name, set()).add(index)
        if current == found:
            return found
        found = current
        ScopeTracker.mutating_functions = found


def _resolve_bindings(tree: ast.Module) -> Optional[symbols.SymbolTable]:
    """Resolve lexical bindings on the final scope structure of the tree. A file the resolver
    cannot handle is translated without binding facts, as before the resolver existed."""
    try:
        return symbols.analyze(tree)
    except Exception as exc:  # pragma: no cover - reported, never fatal
        print(f"py2v: bindings not resolved: {type(exc).__name__}: {exc}", file=sys.stderr)
        return None


def _mark_math_members(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """Set `_math_member` on each read of a name bound by a module-level
    `from math import name [as other]` and bound nowhere else: the member's
    name in `math`. The backend spells it as a member of V's math module."""
    if table is None:
        return
    rebound = {b.id for b in table.bindings if b.rebound or b.kind != "import"}
    members: Dict[int, str] = {}
    for statement in tree.body:
        if isinstance(statement, ast.ImportFrom) and statement.module == "math" and statement.level == 0:
            for alias in statement.names:
                binding = getattr(alias, "_binding", None)
                if binding is not None and binding not in rebound:
                    members[binding] = alias.name
        # `from random import name` rides along, spelled `random.name`.
        if isinstance(statement, ast.ImportFrom) and statement.module == "random" and statement.level == 0:
            for alias in statement.names:
                binding = getattr(alias, "_binding", None)
                if binding is not None and binding not in rebound:
                    members[binding] = "random." + alias.name
    if not members:
        return
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load):
            member = members.get(getattr(node, "_binding", None))
            if member:
                node._math_member = member


def _annotation_for_type(types: List[Dict[str, Any]], type_id: int) -> Optional[str]:
    """The Python annotation that spells a fully known inferred type, or None."""
    entry = types[type_id]
    kind = entry["k"]
    if kind in ("int", "float", "str", "bool"):
        return kind
    if kind == "list":
        elem = _annotation_for_type(types, entry["elem"])
        return f"list[{elem}]" if elem else None
    if kind == "dict":
        key = _annotation_for_type(types, entry["key"])
        value = _annotation_for_type(types, entry["value"])
        return f"dict[{key}, {value}]" if key in ("str", "int") and value else None
    return None


def _is_empty_container(node: ast.expr) -> bool:
    if isinstance(node, ast.List):
        return not node.elts
    if isinstance(node, ast.Dict):
        return not node.keys
    return (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
            and node.func.id in ("list", "dict") and not node.args and not node.keywords
            and getattr(node.func, "_binding", None) is None)


@dataclass
class ProjectFacts:
    """What the other files of the project export: summaries from `--summaries`, and this
    file's own dotted name among them."""
    externals: Dict[str, Any] = field(default_factory=dict)
    module_name: Optional[str] = None
    is_package: bool = False


def _project_files(root: str) -> List[Tuple[str, str, bool]]:
    """Every Python file under root with its dotted module name, named as inference names
    them, so a summary and the file it describes agree."""
    directory = infer.Path(root).resolve()
    skipped = ("__pycache__", ".venv", "venv", ".git", "node_modules")
    found = []
    for path in sorted(directory.rglob("*.py"), key=lambda p: p.as_posix()):
        if path.is_symlink() or not path.is_file():
            continue
        if any(part in skipped for part in path.relative_to(directory).parts):
            continue
        name, is_package = infer._project_module(directory, path)
        found.append((str(path), name, is_package))
    return found


def write_summaries(root: str, out_path: str) -> None:
    """Summarize every module under root for the other modules (at most three rounds, as
    a summary can depend on another), and write {module name: summary} as JSON. A module
    is also listed under its name with and without the root directory's name in front,
    since a project spells its own imports either way."""
    parsed = []
    for path, name, is_package in _project_files(root):
        try:
            with open(path, "r", encoding="utf-8") as handle:
                tree = ast.parse(handle.read(), filename=path)
            parsed.append((name, is_package, tree, symbols.analyze(tree)))
        except Exception:
            continue  # the per-file run reports what is wrong with this file
    summaries: Dict[str, Any] = {}
    for _ in range(3):
        upcoming: Dict[str, Any] = {}
        for name, is_package, tree, table in parsed:
            try:
                infer.run(tree, table, externals=summaries, module_name=name,
                          is_package=is_package)
                upcoming[name] = infer.summarize(tree, table, module_name=name,
                                                 is_package=is_package)
            except Exception:
                continue
        settled = json.dumps(upcoming, sort_keys=True) == json.dumps(summaries, sort_keys=True)
        summaries = upcoming
        if settled:
            break
    prefix = os.path.basename(os.path.abspath(root)) + "."
    for name in list(summaries):
        other = name[len(prefix):] if name.startswith(prefix) else prefix + name
        summaries.setdefault(other, summaries[name])
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(summaries, handle)


def _load_project_facts(externals_path: str, root: str, file_path: str) -> ProjectFacts:
    with open(externals_path, "r", encoding="utf-8") as handle:
        externals = json.load(handle)
    directory = infer.Path(root).resolve()
    name, is_package = infer._project_module(directory, infer.Path(file_path).resolve())
    return ProjectFacts(externals, name, is_package)


def _infer_types(tree: ast.Module, table: Optional[symbols.SymbolTable],
                 project: Optional[ProjectFacts] = None) -> Optional[infer.TypeFacts]:
    """The types the code shows, or None for a file inference cannot handle; such a file
    is translated without them, as before inference existed."""
    if table is None:
        return None
    # Inference clears `_api` before it runs. The marks set by `_mark_runtime_api` are the
    # ones the backend knows how to emit, so they are kept across the run.
    marks = [(node, node._api) for node in ast.walk(tree) if getattr(node, "_api", "")]
    try:
        return _run_inference(tree, table, project)
    finally:
        for node, mark in marks:
            node._api = mark


def _run_inference(tree: ast.Module, table: symbols.SymbolTable,
                   project: Optional[ProjectFacts] = None) -> Optional[infer.TypeFacts]:
    try:
        if project is not None:
            return infer.run(tree, table, externals=project.externals,
                             module_name=project.module_name, is_package=project.is_package)
        return infer.run(tree, table)
    except Exception as exc:  # pragma: no cover - reported, never fatal
        print(f"py2v: types not inferred: {type(exc).__name__}: {exc}", file=sys.stderr)
        return None


_SIZED_KINDS = ("list", "dict", "set", "tuple", "tuple_of", "bytes")


def _truth_kind(node: ast.expr, facts: infer.TypeFacts) -> str:
    """The kind of a tested value: the type the code shows, else the one its annotations
    declare (inference's assumed layer)."""
    type_id = getattr(node, "_assumed", None)
    if type_id is None:
        type_id = getattr(node, "_type", None)
    return facts.types[type_id]["k"] if type_id is not None else "unknown"


def _expand_bool_calls(tree: ast.Module) -> None:
    """The builtin bool(x) is exactly not not x, including its one truth evaluation."""
    class Lower(ast.NodeTransformer):
        def visit_Call(self, node: ast.Call) -> ast.AST:
            self.generic_visit(node)
            if (isinstance(node.func, ast.Name) and node.func.id == "bool"
                    and getattr(node.func, "_binding", None) is None
                    and len(node.args) == 1 and not node.keywords
                    and not isinstance(node.args[0], ast.Starred)):
                inner = ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=node.args[0]), node)
                return ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=inner), node)
            return node
    Lower().visit(tree)


def _lower_optional_text_calls(tree: ast.Module, table: Optional[symbols.SymbolTable],
                               facts: Optional[infer.TypeFacts]) -> None:
    """A runtime call that gives text or None (`os.environ.get(name)`), used where Python
    asks for its truth or chooses with `or`: `if call:` becomes `pyrt.has_text(call)`,
    `call or "text"` becomes `pyrt.text_or(call, "text")` and `call or other_call` becomes
    `pyrt.first_text(call, other_call)`. The call runs once. The right side of an `or` runs
    whether or not it is needed, so it is taken only when it is a constant, a name, or
    another runtime call that cannot fail."""
    if table is None or facts is None or any(b.name == "pyrt" for b in table.bindings):
        return
    api = _runtime_api()

    def optional_text(node: ast.AST) -> bool:
        entry = api.get(getattr(node, "_api", "")) if isinstance(node, ast.Call) else None
        return bool(entry) and entry.get("returns") == "str | None" and not entry.get("raises")

    def helper(name: str, args: List[ast.expr], like: ast.AST) -> ast.expr:
        call = _runtime_call(name, args, like)
        call._dynamic = False
        return call

    def text(node: ast.expr) -> bool:
        if not (isinstance(node, (ast.Constant, ast.Name))
                or isinstance(node, ast.Call) and getattr(node, "_api", "")
                and not api.get(node._api, {}).get("raises")):
            return False
        return _truth_kind(node, facts) == "str"

    tested = set()

    def mark(node: ast.expr) -> None:
        tested.add(id(node))
        if isinstance(node, ast.BoolOp):
            for value in node.values:
                mark(value)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            mark(node.operand)

    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.While, ast.IfExp, ast.Assert)):
            mark(node.test)
        elif isinstance(node, ast.comprehension):
            for condition in node.ifs:
                mark(condition)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            mark(node.operand)

    class Lower(ast.NodeTransformer):
        def visit_Call(self, node: ast.Call) -> ast.AST:
            was_tested = id(node) in tested
            self.generic_visit(node)
            if was_tested and optional_text(node):
                return helper("has_text", [node], node)
            return node

        def visit_BoolOp(self, node: ast.BoolOp) -> ast.AST:
            was_tested = id(node) in tested
            self.generic_visit(node)
            if was_tested or not isinstance(node.op, ast.Or) or not optional_text(node.values[0]):
                return node
            if not all(optional_text(v) or text(v) for v in node.values[1:]):
                return node
            result = node.values[0]
            is_text = False
            for value in node.values[1:]:
                if is_text:
                    return node  # text first: `_choose_boolop_values` has that form
                if optional_text(value):
                    result = helper("first_text", [result, value], node)
                else:
                    result = helper("text_or", [result, value], node)
                    is_text = True
                    for name in ("_type", "_assumed"):
                        if hasattr(value, name):
                            setattr(result, name, getattr(value, name))
            return result

    try:
        Lower().visit(tree)
    except RecursionError:
        pass


def _choose_boolop_values(tree: ast.Module, facts: Optional[infer.TypeFacts]) -> None:
    """`a or b` and `a and b` used for their value, not as a condition, become the choice
    Python makes: `a if a else b` and `b if a else a` (`name = given or "default"`). V's
    `||` and `&&` take and give bool only. Done when every operand has the same known
    str, int, float, list or dict type and each one but the last is a plain name or an attribute
    of one, so that reading it twice is safe; `_state_truth_tests` then states the test."""
    if facts is None:
        return
    tested = set()

    def mark(node: ast.expr) -> None:
        if isinstance(node, ast.BoolOp):
            tested.add(id(node))
            for value in node.values:
                mark(value)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            mark(node.operand)

    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.While, ast.IfExp, ast.Assert)):
            mark(node.test)
        elif isinstance(node, ast.comprehension):
            for condition in node.ifs:
                mark(condition)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            mark(node.operand)

    def empty(node: ast.expr) -> bool:
        return (isinstance(node, ast.List) and not node.elts
                or isinstance(node, ast.Dict) and not node.keys)

    def annotation(type_id: int) -> "Optional[str]":
        item = facts.types[type_id]
        if item["k"] in ("dynamic", "unknown"):
            return "Any"
        if item["k"] == "list":
            inner = annotation(item["elem"])
            return f"list[{inner}]" if inner else None
        if item["k"] == "dict":
            key, value = annotation(item["key"]), annotation(item["value"])
            return f"dict[{key}, {value}]" if key in ("str", "int") and value else None
        return _annotation_for_type(facts.types, type_id)

    def spelled(node: ast.expr, or_none: bool = False) -> Optional[str]:
        if isinstance(node, ast.Constant) and type(node.value) is float:
            return "float"
        type_id = getattr(node, "_represented", getattr(node, "_assumed", None))
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is not None and or_none and facts.types[type_id]["k"] == "union":
            # `T | None`: the T
            members = [m for m in facts.types[type_id]["members"]
                       if facts.types[m]["k"] != "none"]
            if len(members) == 1 and len(facts.types[type_id]["members"]) == 2:
                type_id = members[0]
        if type_id is None or facts.types[type_id]["k"] not in ("str", "int", "float", "list", "dict"):
            return None
        return annotation(type_id)

    def plain(node: ast.expr) -> bool:
        return (isinstance(node, (ast.Name, ast.Constant))
                or isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub))
                and isinstance(node.operand, ast.Constant) and type(node.operand.value) in (int, float)
                or isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name))

    class Choose(ast.NodeTransformer):
        def visit_BoolOp(self, node: ast.BoolOp) -> ast.AST:
            self.generic_visit(node)
            values: list[ast.expr] = []
            for i, value in enumerate(node.values):
                if isinstance(value, ast.Constant) and not isinstance(value.value, float):
                    stops = bool(value.value) == isinstance(node.op, ast.Or)
                    if stops:
                        values.append(value)
                        break
                    if i < len(node.values) - 1:
                        continue
                values.append(value)
            if len(values) == 1:
                # A bare integral float loses its type in json2; keep the typed
                # choice instead of introducing such a literal as the result.
                if isinstance(values[0], ast.Constant) and isinstance(values[0].value, float):
                    return node
                return values[0]
            node.values = values
            if id(node) in tested:
                return node
            kinds = {spelled(value) for value in node.values if not empty(value)}
            if isinstance(node.op, ast.Or) and (len(kinds) != 1 or None in kinds):
                # `given or "default"` where the earlier values may be None: the last one,
                # which is not, decides the type
                kinds = {spelled(value, or_none=True) for value in node.values[:-1]
                         if not empty(value)}
                if not empty(node.values[-1]):
                    kinds.add(spelled(node.values[-1]))
            if len(kinds) != 1 or None in kinds or not all(plain(v) for v in node.values[:-1]):
                return node
            text = next(iter(kinds))
            for value in node.values:
                if empty(value):
                    if (isinstance(value, ast.List) and not text.startswith("list[")
                            or isinstance(value, ast.Dict) and not text.startswith("dict[")):
                        return node
                    value._runtime_annotation = text
            result = node.values[-1]
            for value in reversed(node.values[:-1]):
                again = copy.deepcopy(value)
                if isinstance(node.op, ast.Or):
                    result = ast.IfExp(test=value, body=again, orelse=result)
                else:
                    result = ast.IfExp(test=value, body=result, orelse=again)
                ast.copy_location(result, node)
                for name in ("_type", "_assumed"):
                    if hasattr(node.values[-1], name):
                        setattr(result, name, getattr(node.values[-1], name))
            return result

    try:
        Choose().visit(tree)
    except RecursionError:
        pass


def _state_truth_tests(tree: ast.Module, table: Optional[symbols.SymbolTable],
                       facts: Optional[infer.TypeFacts]) -> None:
    """Write the test Python makes when a str, number or container is used as a condition:
    `if name:` becomes `if name != "":`, `if not items:` becomes `if not len(items) > 0:`.
    V conditions are bool only. Dynamic storage is left for runtime truth lowering."""
    if table is None or facts is None:
        return
    context = AnalysisContext(table=table, facts=facts)
    native_maps = {getattr(n.target, "_binding", None) for n in ast.walk(tree)
                   if isinstance(n, ast.AnnAssign) and context.native_map_annotation(n)}
    runtime_available = not any(b.name == "pyrt" for b in table.bindings)
    optional_dynamic = set()
    for declaration in ast.walk(tree):
        annotation = (declaration.annotation if isinstance(declaration, (ast.arg, ast.AnnAssign))
                      else None)
        target = declaration.target if isinstance(declaration, ast.AnnAssign) else declaration
        if annotation is not None and isinstance(target, (ast.arg, ast.Name)):
            text = _unparse_expr(annotation).replace("typing.", "").replace(" ", "")
            if text in ("Optional[Any]", "Any|None", "None|Any",
                        "Optional[object]", "object|None", "None|object"):
                optional_dynamic.add(getattr(target, "_binding", None))
    # These APIs return Python lists as well as native V arrays. Iterator APIs
    # such as re.finditer also emit arrays, but their Python truth is always true.
    list_apis = {"sqlite3.Cursor.fetchall", "sqlite3.Cursor.fetchmany",
                 "re.findall", "re.Pattern.findall", "re.split", "re.Pattern.split"}
    list_assignments: dict[int, list[ast.expr]] = {}
    for stmt in ast.walk(tree):
        target = (stmt.targets[0] if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1
                  else stmt.target if isinstance(stmt, ast.AnnAssign) else None)
        binding = getattr(target, "_binding", None) if isinstance(target, ast.Name) else None
        if binding is not None and stmt.value is not None:
            list_assignments.setdefault(binding, []).append(stmt.value)
    list_bindings = {b for b, values in list_assignments.items()
                     if len(table.bindings[b].sites) == len(values)
                     and all(isinstance(value, ast.Call) and getattr(value, "_api", "") in list_apis
                             for value in values)}

    def runtime_list(node: ast.expr) -> bool:
        return (isinstance(node, ast.Call) and getattr(node, "_api", "") in list_apis
                or isinstance(node, ast.Name) and getattr(node, "_binding", None) in list_bindings)

    len_is_builtin = not any(b.name == "len" for b in table.bindings)
    # Classes whose instances can be false: they define their own truth or length.
    falsy_classes = {cls.name for cls in ast.walk(tree) if isinstance(cls, ast.ClassDef)
                     and any(isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))
                             and m.name in ("__bool__", "__len__") for m in cls.body)}
    local_hooks = {}
    for cls in ast.walk(tree):
        if not isinstance(cls, ast.ClassDef):
            continue
        # Inheritance, metaclasses, and decorators may supply truth hooks.
        if cls.decorator_list or cls.keywords or (cls.bases and not (
                len(cls.bases) == 1 and isinstance(cls.bases[0], ast.Name)
                and cls.bases[0].id == "object")):
            continue
        if any(isinstance(stmt, ast.Assign)
               and any(isinstance(t, ast.Name) and t.id in ("__bool__", "__len__")
                       for t in stmt.targets)
               or isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name)
               and stmt.target.id in ("__bool__", "__len__")
               or isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef))
               and stmt.name in ("__bool__", "__len__") and stmt.decorator_list
               for stmt in cls.body):
            continue
        methods = {m.name for m in cls.body
                   if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))}
        hook = "bool" if "__bool__" in methods else "len" if "__len__" in methods else "always"
        local_hooks[getattr(cls, "_binding", None)] = hook
    local_hooks.pop(None, None)

    def local_truth_hook(node: ast.expr) -> str:
        type_id = getattr(node, "_represented", getattr(node, "_assumed", None))
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is None or facts.types[type_id]["k"] != "instance":
            return ""
        return local_hooks.get(facts.types[type_id].get("class_binding"), "")


    def optional_instance(node: ast.expr) -> bool:
        """An optional local instance without truth hooks, Path or SQLite handle:
        these instances are always true, so their optional truth is `is not None`."""
        type_id = getattr(node, "_represented", getattr(node, "_assumed", None))
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is None or facts.types[type_id]["k"] != "union":
            return False
        members = [facts.types[m] for m in facts.types[type_id]["members"]]
        others = [m for m in members if m["k"] != "none"]
        return (len(members) == 2 and len(others) == 1 and others[0]["k"] == "instance"
                and (others[0].get("name") in (
                    "pathlib.Path", "sqlite3.Connection", "sqlite3.Cursor")
                     or others[0].get("class_binding") is not None
                     and others[0].get("name") not in falsy_classes))

    def reference(node: ast.AST) -> bool:
        # a name or a chain of attributes of one: reading it twice reads the same value
        while isinstance(node, ast.Attribute):
            node = node.value
        return isinstance(node, ast.Name)

    # Fields a class of this file declares in its body as `Optional[T]` or `T | None`
    # with a plain T, by the class's binding: a dataclass states its fields there.
    plain_names = {"str": "str", "int": "int", "float": "float", "bool": "bool",
                   "list": "list", "dict": "dict", "set": "set", "List": "list",
                   "Dict": "dict", "Set": "set"}
    optional_fields: Dict[Tuple[int, str], str] = {}
    for cls in ast.walk(tree):
        if not isinstance(cls, ast.ClassDef) or getattr(cls, "_binding", None) is None:
            continue
        for stmt in cls.body:
            if not (isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name)):
                continue
            text = _unparse_expr(stmt.annotation).replace("typing.", "")
            inner = ""
            if text.startswith("Optional[") and text.endswith("]"):
                inner = text[9:-1]
            elif text.endswith(" | None"):
                inner = text[:-7]
            elif text.startswith("None | "):
                inner = text[7:]
            head = inner.split("[", 1)[0]
            if head in plain_names and "|" not in inner:
                optional_fields[(cls._binding, stmt.target.id)] = plain_names[head]

    def declared_optional_field(node: ast.expr) -> str:
        if not isinstance(node, ast.Attribute):
            return ""
        owner = getattr(node.value, "_assumed", None)
        if owner is None:
            owner = getattr(node.value, "_type", None)
        if owner is None or facts.types[owner]["k"] != "instance":
            return ""
        kind = optional_fields.get((facts.types[owner].get("class_binding"), node.attr), "")
        return kind if kind in ("str", "int", "float", "bool") or len_is_builtin else ""

    def optional_plain(node: ast.expr) -> str:
        """The kind of the other member when the value is None or one plain type (str, int,
        float, bool or a sized container) and is a plain reference; else an empty string."""
        if not reference(node):
            return ""
        if (runtime_available and isinstance(node, ast.Name)
                and getattr(node, "_binding", None) in optional_dynamic):
            return "dynamic"
        represented = getattr(node, "_represented", None)
        if (represented is not None and facts.types[represented]["k"] in
                ("dynamic", "str", "int", "float", "bool") + _SIZED_KINDS):
            return declared_optional_field(node)
        # Either layer may show it: where a branch looks unreachable to the annotated
        # layer, the evidence layer still has the declared union.
        for layer in ("_represented", "_assumed", "_type"):
            type_id = getattr(node, layer, None)
            if type_id is None or facts.types[type_id]["k"] != "union":
                continue
            members = [facts.types[m] for m in facts.types[type_id]["members"]]
            others = [m["k"] for m in members if m["k"] != "none"]
            if len(members) != 2 or len(others) != 1:
                return ""
            kind = others[0]
            if (kind in ("str", "int", "float", "bool")
                    or kind == "dynamic" and runtime_available
                    or kind in _SIZED_KINDS and len_is_builtin):
                return kind
            return ""
        return declared_optional_field(node)

    def native_always_true(node: ast.expr) -> bool:
        type_id = getattr(node, "_represented", getattr(node, "_assumed", None))
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is None:
            return False
        item = facts.types[type_id]
        return (item["k"] == "callable" or item["k"] == "instance"
                and (item.get("name") in ("pathlib.Path", "sqlite3.Connection", "sqlite3.Cursor", "re.Match")
                     or local_truth_hook(node) == "always"))

    def stated(node: ast.expr) -> ast.expr:
        hook = local_truth_hook(node)
        if hook in ("bool", "len"):
            method = ast.copy_location(
                ast.Call(func=ast.Attribute(value=node,
                                            attr="to_bool" if hook == "bool" else "len",
                                            ctx=ast.Load()), args=[], keywords=[]), node)
            if hook == "bool":
                return method
            return _runtime_call("truth_length", [method], node)
        if (isinstance(node, ast.Constant) and node.value is None
                or isinstance(node, (ast.List, ast.Tuple)) and not node.elts):
            return ast.copy_location(ast.Constant(value=False), node)
        if isinstance(node, ast.BoolOp):
            node.values = [stated(v) for v in node.values]
            return node
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            node.operand = stated(node.operand)
            return node
        if runtime_available and native_always_true(node):
            return _runtime_call("instance_truth", [node], node)
        plain = optional_plain(node)
        represented = getattr(node, "_represented", None)
        if (represented is not None and facts.types[represented]["k"] == "dynamic"
                and not runtime_list(node)
                and not plain
                and not any(isinstance(n, ast.Name) and getattr(n, "_binding", None) in native_maps
                            for n in ast.walk(node))):
            return node
        if isinstance(node, ast.Call) and runtime_available:
            type_id = getattr(node, "_represented", getattr(node, "_assumed", None))
            if type_id is not None and facts.types[type_id]["k"] == "union":
                members = [facts.types[m]["k"] for m in facts.types[type_id]["members"]]
                if len(members) == 2 and set(members) == {"str", "none"}:
                    test = _runtime_call("has_text", [node], node)
                    test._dynamic = False
                    test._runtime_annotation = "bool"
                    return test
        if plain:
            # `value` that may be None or a str, number or container: not None, and then
            # the test of that type. V narrows the option within the one condition.
            present = ast.Compare(left=node, ops=[ast.IsNot()],
                                  comparators=[ast.Constant(value=None)])
            again = copy.deepcopy(node)
            if plain == "str":
                rest: ast.expr = ast.Compare(left=again, ops=[ast.NotEq()],
                                             comparators=[ast.Constant(value="")])
            elif plain in ("int", "float"):
                rest = ast.Compare(left=again, ops=[ast.NotEq()],
                                   comparators=[ast.Constant(value=0 if plain == "int" else 0.0)])
            elif plain == "bool":
                rest = again
            elif plain == "dynamic":
                rest = _runtime_call("truth", [again], node)
            else:
                size = ast.Call(func=ast.Name(id="len", ctx=ast.Load()), args=[again], keywords=[])
                rest = ast.Compare(left=size, ops=[ast.Gt()], comparators=[ast.Constant(value=0)])
            both = ast.BoolOp(op=ast.And(), values=[present, rest])
            for part in ast.walk(both):
                if not hasattr(part, "lineno"):
                    ast.copy_location(part, node)
            return both
        storage_kind = facts.types[represented]["k"] if represented is not None else ""
        kind = ("list" if runtime_list(node)
                else storage_kind if storage_kind in ("str", "int", "float", "bool") + _SIZED_KINDS
                else _truth_kind(node, facts))
        if optional_instance(node):
            new: ast.expr = ast.Compare(left=node, ops=[ast.IsNot()],
                                        comparators=[ast.Constant(value=None)])
        elif kind == "str":
            new = ast.Compare(left=node, ops=[ast.NotEq()],
                              comparators=[ast.Constant(value="")])
        elif kind == "int":
            new = ast.Compare(left=node, ops=[ast.NotEq()], comparators=[ast.Constant(value=0)])
        elif kind == "float":
            new = ast.Compare(left=node, ops=[ast.NotEq()],
                              comparators=[ast.Constant(value=0.0)])
        elif kind in _SIZED_KINDS and len_is_builtin:
            size = ast.Call(func=ast.Name(id="len", ctx=ast.Load()), args=[node], keywords=[])
            new = ast.Compare(left=size, ops=[ast.Gt()], comparators=[ast.Constant(value=0)])
        else:
            return node
        for part in ast.walk(new):
            if part is not node and not hasattr(part, "lineno"):
                ast.copy_location(part, node)
        return new

    def has_walrus(node: ast.expr) -> bool:
        return any(isinstance(n, ast.NamedExpr) for n in ast.walk(node))

    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.While, ast.IfExp, ast.Assert)):
            if not has_walrus(node.test):
                node.test = stated(node.test)
        elif isinstance(node, ast.comprehension):
            node.ifs = [c if has_walrus(c) else stated(c) for c in node.ifs]
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            # `not value` tests its operand wherever it stands
            if not has_walrus(node.operand):
                node.operand = stated(node.operand)


def _iterate_string_characters(tree: ast.Module, facts: Optional[infer.TypeFacts]) -> None:
    """A loop or comprehension over a str visits its characters as strs. V iterates a string
    by byte, so the iterable becomes `s.split("")`, which the backend emits as it stands and
    which in V is the list of the string's characters. (Python itself refuses an empty
    separator; the form exists only between this pass and the backend.)"""
    if facts is None:
        return

    def characters(iterable: ast.expr) -> ast.expr:
        if _truth_kind(iterable, facts) != "str":
            return iterable
        new = ast.Call(func=ast.Attribute(value=iterable, attr="split", ctx=ast.Load()),
                       args=[ast.Constant(value="")], keywords=[])
        for part in ast.walk(new):
            if part is not iterable and not hasattr(part, "lineno"):
                ast.copy_location(part, iterable)
        return new

    for node in ast.walk(tree):
        if isinstance(node, (ast.For, ast.AsyncFor, ast.comprehension)):
            node.iter = characters(node.iter)


def _state_module_name(tree: ast.Module, module_name: Optional[str]) -> None:
    """`__name__` read as a value is the module's name: its dotted name inside a project,
    `"__main__"` for a file translated on its own (it is the program). The
    `if __name__ == "__main__":` guard was rewritten before this."""
    name = module_name or "__main__"

    class Name(ast.NodeTransformer):
        def visit_Name(self, node: ast.Name) -> ast.AST:
            if node.id == "__name__" and isinstance(node.ctx, ast.Load):
                return ast.copy_location(ast.Constant(value=name), node)
            return node

    if not any(isinstance(n, ast.Name) and n.id == "__name__" and isinstance(n.ctx, ast.Store)
               for n in ast.walk(tree)):
        Name().visit(tree)


def _lower_dataclass_fields(tree: ast.Module) -> None:
    """A class attribute declared with `dataclasses.field(...)` gets the default the call
    describes: `field(default=v)` is `v`, `field(default_factory=list)` (or `dict`, `set`) is
    the empty container the declared type already starts as, `field(default_factory=lambda: e)` is `e`, and any other factory
    `f` is `f()`. V gives every instance its own value of a field default, as the factory
    does. A `field(...)` with neither keeps no default. Only where `field` is imported
    from `dataclasses` and not bound again at module level."""
    names: Set[str] = set()
    positional: Set[str] = set()
    modules: Set[str] = set()
    for stmt in tree.body:
        if isinstance(stmt, ast.ImportFrom) and stmt.module == "dataclasses" and stmt.level == 0:
            names.update(a.asname or a.name for a in stmt.names if a.name == "field")
        elif isinstance(stmt, ast.ImportFrom) and stmt.module == "pydantic" and stmt.level == 0:
            # pydantic's `Field(default, ...)`: the default is kept, the validation
            # keywords (`ge`, `max_length`, `description`) have no V counterpart here
            positional.update(a.asname or a.name for a in stmt.names if a.name == "Field")
        elif isinstance(stmt, ast.Import):
            modules.update(a.asname or a.name for a in stmt.names if a.name == "dataclasses")
    for stmt in tree.body:
        bound = []
        if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            bound = [stmt.name]
        elif isinstance(stmt, ast.Assign):
            bound = [t.id for t in stmt.targets if isinstance(t, ast.Name)]
        names.difference_update(bound)
        positional.difference_update(bound)
        modules.difference_update(bound)
    if not names and not modules and not positional:
        return

    def is_field(call: ast.AST) -> bool:
        if not isinstance(call, ast.Call):
            return False
        if isinstance(call.func, ast.Name) and call.func.id in positional:
            return len(call.args) <= 1 and not any(isinstance(a, ast.Starred) for a in call.args)
        if call.args:
            return False
        if isinstance(call.func, ast.Name):
            return call.func.id in names
        return (isinstance(call.func, ast.Attribute) and call.func.attr == "field"
                and isinstance(call.func.value, ast.Name) and call.func.value.id in modules)

    for cls in ast.walk(tree):
        if not isinstance(cls, ast.ClassDef):
            continue
        for stmt in cls.body:
            if not (isinstance(stmt, ast.AnnAssign) and stmt.value is not None and is_field(stmt.value)):
                continue
            keywords = {k.arg: k.value for k in stmt.value.keywords if k.arg is not None}
            value: Optional[ast.expr] = None
            first = stmt.value.args[0] if stmt.value.args else None
            if first is not None and not (isinstance(first, ast.Constant) and first.value is Ellipsis):
                value = first  # `Field(0.5, ...)`; `Field(...)` marks a required field
            elif "default" in keywords:
                value = keywords["default"]
            elif "default_factory" in keywords:
                factory = keywords["default_factory"]
                if isinstance(factory, ast.Name) and factory.id in ("list", "dict", "set"):
                    # V's zero value of the declared type is the empty container
                    value = None
                elif isinstance(factory, ast.Lambda) and not (
                        factory.args.args or factory.args.vararg or factory.args.kwarg
                        or factory.args.kwonlyargs or factory.args.posonlyargs):
                    value = factory.body
                else:
                    value = ast.Call(func=factory, args=[], keywords=[])
            if value is not None:
                for part in ast.walk(value):
                    if not hasattr(part, "lineno"):
                        ast.copy_location(part, stmt.value)
            stmt.value = value


def _drop_doctest_runs(tree: ast.Module) -> None:
    """`doctest.testmod()` runs the examples in docstrings, which a translation does not
    carry: the call is left out."""
    names = {"testmod"} if any(
        isinstance(n, ast.ImportFrom) and n.module == "doctest"
        and any(a.name == "testmod" and a.asname is None for a in n.names)
        for n in ast.walk(tree)) else set()

    def is_run(stmt: ast.stmt) -> bool:
        if not (isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Call)):
            return False
        func = stmt.value.func
        if isinstance(func, ast.Name):
            return func.id in names
        return (isinstance(func, ast.Attribute) and func.attr == "testmod"
                and isinstance(func.value, ast.Name) and func.value.id == "doctest")

    for node in ast.walk(tree):
        for field_name in ("body", "orelse", "finalbody"):
            block = getattr(node, field_name, None)
            if isinstance(block, list) and any(isinstance(s, ast.stmt) and is_run(s) for s in block):
                kept = [s for s in block if not (isinstance(s, ast.stmt) and is_run(s))]
                block[:] = kept or [ast.copy_location(ast.Pass(), block[0])]


def _runtime_call(name: str, args: List[ast.expr], like: ast.AST) -> ast.expr:
    """`pyrt.<name>(args)`, the runtime's form of an operation on a value of unknown type."""
    if (name == "box" and len(args) == 1 and isinstance(args[0], ast.Constant)
            and args[0].value is None):
        # None has no V type to box: it is the runtime's own None
        none = ast.Attribute(value=ast.Name(id="pyrt", ctx=ast.Load()), attr="none_",
                             ctx=ast.Load())
        for part in ast.walk(none):
            ast.copy_location(part, like)
        none._dynamic = True
        return none
    if name == "box" and len(args) == 1 and (
            isinstance(args[0], ast.List) and not args[0].elts
            or isinstance(args[0], ast.Dict) and not args[0].keys):
        # An empty display has no element type for V to box: the runtime makes it.
        name = "empty_list" if isinstance(args[0], ast.List) else "empty_dict"
        args = []
    call = ast.Call(func=ast.Attribute(value=ast.Name(id="pyrt", ctx=ast.Load()), attr=name,
                                       ctx=ast.Load()), args=args, keywords=[])
    for part in ast.walk(call):
        if not hasattr(part, "lineno"):
            ast.copy_location(part, like)
    result_types = {"length": "int", "truth": "bool", "truth_option": "bool", "instance_truth": "bool", "truth_length": "bool", "eq": "bool", "has": "bool", "is_none": "bool",
                    "str": "string", "to_int": "int", "to_float": "float",
                    "to_str": "string", "to_bool": "bool", "elements": "list[Any]",
                    "unpack": "list[Any]"}
    call._runtime_annotation = result_types.get(name, "")
    call._dynamic = not call._runtime_annotation
    return call


def _annotate_parameters_from_calls(tree: ast.Module, table: Optional[symbols.SymbolTable],
                                    facts: Optional[infer.TypeFacts]) -> None:
    """In a file translated on its own every call of its functions is in the file, so a
    parameter without an annotation takes the type its calls give it, when that is one
    plain type (`def biggest(xs)` called with `[3, 9, 4]` becomes `xs: list[int]`). A
    function that is also used as a value is left alone: such a call is not visible."""
    if table is None or facts is None:
        return
    used_as_value = set()
    called = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            called.add(id(node.func))
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and id(node) not in called:
            used_as_value.add(getattr(node, "_binding", None))
    known = {b["id"]: b.get("inferred") for b in facts.bindings}
    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        if fn.decorator_list or getattr(fn, "_binding", None) in used_as_value:
            continue
        positional = fn.args.posonlyargs + fn.args.args
        for position, arg in enumerate(positional + fn.args.kwonlyargs):
            if arg.annotation is not None or (position == 0 and arg.arg in ("self", "cls")):
                continue
            type_id = known.get(getattr(arg, "_binding", None))
            if type_id is None:
                continue
            text = _annotation_for_type(facts.types, type_id)
            if text:
                arg.annotation = _annotation_node(text, arg)


def _annotate_returns(tree: ast.Module, facts: Optional[infer.TypeFacts]) -> None:
    """A function without a return annotation takes the return type its body shows, when
    that is one plain type."""
    if facts is None:
        return
    returns = {f["scope"]: f.get("ret_inferred") for f in facts.functions}
    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)) or fn.returns is not None:
            continue
        if fn.decorator_list or _is_generator(fn):
            continue
        type_id = returns.get(getattr(fn, "_scope_id", None))
        if type_id is None:
            continue
        text = _annotation_for_type(facts.types, type_id)
        if text:
            fn.returns = _annotation_node(text, fn)


def _lower_exit_statements(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """A resolved exit statement raises SystemExit with its original argument."""
    if table is None:
        return
    builtin_imports = {
        getattr(alias, "_binding", None)
        for stmt in ast.walk(tree)
        if isinstance(stmt, ast.ImportFrom) and stmt.module == "builtins" and stmt.level == 0
        for alias in stmt.names if alias.name == "SystemExit"
    }
    for stmt in ast.walk(tree):
        if not isinstance(stmt, ast.Raise) or stmt.exc is None:
            continue
        name = stmt.exc.func if isinstance(stmt.exc, ast.Call) else stmt.exc
        if (isinstance(name, ast.Name) and name.id == "SystemExit"
                and getattr(name, "_binding", None) is not None
                and getattr(name, "_binding") not in builtin_imports):
            # The runtime currently treats the *spelling* SystemExit as the
            # built-in exception. Do not silently exit for a user-defined name.
            raise SyntaxError(f"py2v cannot lower shadowed SystemExit at line {stmt.lineno}")
    if any(binding.name == "SystemExit" for binding in table.bindings):
        return
    imported: Dict[int, str] = {}
    import_lines: Dict[int, int] = {}
    for stmt in tree.body:
        if isinstance(stmt, ast.Import):
            for alias in stmt.names:
                binding = getattr(alias, "_binding", None)
                if binding is not None and alias.name == "sys" and not table.bindings[binding].rebound:
                    imported[binding] = "sys"
                    import_lines[binding] = stmt.lineno
        elif isinstance(stmt, ast.ImportFrom) and stmt.module == "sys" and stmt.level == 0:
            for alias in stmt.names:
                binding = getattr(alias, "_binding", None)
                if binding is not None and alias.name == "exit" and not table.bindings[binding].rebound:
                    imported[binding] = "sys.exit"
                    import_lines[binding] = stmt.lineno

    changed = any(isinstance(node, ast.Attribute) and node.attr == "exit"
                  and isinstance(node.ctx, (ast.Store, ast.Del))
                  and isinstance(node.value, ast.Name)
                  and imported.get(getattr(node.value, "_binding", None)) == "sys"
                  for node in ast.walk(tree))

    def exit_call(node: ast.Call) -> bool:
        if isinstance(node.func, ast.Name):
            binding = getattr(node.func, "_binding", None)
            return (binding is None and node.func.id in ("exit", "quit")
                    or not changed and imported.get(binding) == "sys.exit"
                    and import_lines[binding] < node.lineno)
        if isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            binding = getattr(node.func.value, "_binding", None)
            return (not changed and node.func.attr == "exit" and imported.get(binding) == "sys"
                    and import_lines[binding] < node.lineno)
        return False

    class Lower(ast.NodeTransformer):
        def visit_Try(self, node: ast.Try) -> ast.AST:
            # A bare finally can be run before the exit. Catching SystemExit
            # still requires guarded exception lowering.
            return node if node.finalbody and node.handlers else self.generic_visit(node)

        def visit_With(self, node: ast.With) -> ast.AST:
            return node

        def visit_AsyncWith(self, node: ast.AsyncWith) -> ast.AST:
            return node

        def visit_Expr(self, node: ast.Expr) -> ast.AST:
            call = node.value
            if (isinstance(call, ast.Call) and exit_call(call) and len(call.args) <= 1
                    and not call.keywords and not any(isinstance(arg, ast.Starred) for arg in call.args)):
                args = [_runtime_call("box", [arg], arg)
                        if isinstance(arg, ast.Constant) and arg.value is None else arg for arg in call.args]
                exc = ast.copy_location(ast.Call(
                    func=ast.copy_location(ast.Name(id="SystemExit", ctx=ast.Load()), node),
                    args=args, keywords=[]), node)
                return ast.copy_location(ast.Raise(exc=exc, cause=None), node)
            return self.generic_visit(node)

    Lower().visit(tree)


def _erase_typing_casts(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """Erase typing's identity call only when its type argument has no runtime effect."""
    if table is None:
        return
    imported: Dict[int, str] = {}
    import_lines: Dict[int, int] = {}
    for stmt in tree.body:
        if isinstance(stmt, ast.Import):
            for alias in stmt.names:
                if alias.name in ("typing", "typing_extensions"):
                    binding = getattr(alias, "_binding", None)
                    if binding is not None and not table.bindings[binding].rebound:
                        imported[binding] = alias.name
                        import_lines[binding] = stmt.lineno
        elif (isinstance(stmt, ast.ImportFrom) and stmt.level == 0
              and stmt.module in ("typing", "typing_extensions")):
            for alias in stmt.names:
                binding = getattr(alias, "_binding", None)
                if binding is not None and not table.bindings[binding].rebound:
                    imported[binding] = stmt.module + "." + alias.name
                    import_lines[binding] = stmt.lineno

    builtin_types = {"int", "float", "str", "bool", "bytes", "list", "dict", "set",
                     "frozenset", "tuple", "object", "type", "complex"}
    arities = {"list": 1, "set": 1, "frozenset": 1, "dict": 2, "type": 1,
               "List": 1, "Set": 1, "FrozenSet": 1, "Dict": 2, "Mapping": 2,
               "MutableMapping": 2, "Sequence": 1, "Iterable": 1, "Iterator": 1,
               "Awaitable": 1, "Optional": 1, "Type": 1}
    atoms = set(arities) | {"Any", "AnyStr", "NoReturn", "Never", "Callable", "Tuple", "Union"}

    def qualified(node: ast.AST) -> str:
        if isinstance(node, ast.Name):
            return imported.get(getattr(node, "_binding", None), "")
        if isinstance(node, ast.Attribute):
            base = qualified(node.value)
            return base + "." + node.attr if base else ""
        return ""

    written = {qualified(node) for node in ast.walk(tree) if isinstance(node, ast.Attribute)
               and isinstance(node.ctx, (ast.Store, ast.Del))}

    def type_name(node: ast.AST) -> str:
        if (isinstance(node, ast.Name) and getattr(node, "_binding", None) is None
                and node.id in builtin_types):
            return node.id
        name = qualified(node)
        if name in written:
            return ""
        tail = name.rsplit(".", 1)[-1]
        return tail if name.startswith(("typing.", "typing_extensions.")) and tail in atoms else ""

    def native_union(node: ast.AST) -> bool:
        if isinstance(node, ast.Name):
            return type_name(node) in builtin_types
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.BitOr):
            if isinstance(node.left, ast.Constant) and node.left.value is None:
                return native_union(node.right)
            if isinstance(node.right, ast.Constant) and node.right.value is None:
                return native_union(node.left)
            return native_union(node.left) and native_union(node.right)
        return False

    def checked_type(node: ast.AST) -> bool:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return False
        if isinstance(node, (ast.Name, ast.Attribute)) and type_name(node) in ("Optional", "Union"):
            return False
        return pure_type(node)

    def pure_type(node: ast.AST) -> bool:
        if isinstance(node, ast.Constant):
            return node.value is None or isinstance(node.value, str)
        if isinstance(node, (ast.Name, ast.Attribute)):
            return bool(type_name(node))
        if isinstance(node, ast.BinOp):
            return sys.version_info >= (3, 10) and native_union(node)
        if not isinstance(node, ast.Subscript):
            return False
        name = type_name(node.value)
        parts = list(node.slice.elts) if isinstance(node.slice, ast.Tuple) else [node.slice]
        # Builtin aliases store parameters without typing's ForwardRef validation.
        parameter = pure_type if name in builtin_types else checked_type
        if name == "Callable" and len(parts) == 2:
            first = parts[0]
            arguments = (isinstance(first, ast.Constant) and first.value is Ellipsis
                         or isinstance(first, ast.List) and all(checked_type(item) for item in first.elts))
            return arguments and checked_type(parts[1])
        if (name in ("tuple", "Tuple") and len(parts) == 2
                and isinstance(parts[1], ast.Constant) and parts[1].value is Ellipsis):
            return parameter(parts[0])
        return (name in arities and len(parts) == arities[name]
                or name in ("tuple", "Tuple", "Union") and bool(parts)) and all(
                    parameter(item) for item in parts)

    class Lower(ast.NodeTransformer):
        def visit_Call(self, node: ast.Call) -> ast.AST:
            self.generic_visit(node)
            name = qualified(node.func)
            if (name in ("typing.cast", "typing_extensions.cast") and len(node.args) == 2
                    and name not in written and not node.keywords
                    and not isinstance(node.args[1], ast.Starred)
                    and (isinstance(node.args[0], ast.Constant) or pure_type(node.args[0]))
                    and all(import_lines.get(getattr(part, "_binding", None), -1) < node.lineno
                            for expression in (node.func, node.args[0]) for part in ast.walk(expression)
                            if isinstance(part, ast.Name))):
                return node.args[1]
            return node

    Lower().visit(tree)


def _lower_frozensets(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """Construct the builtin immutable set through the runtime's iterable adapter."""
    if table is None or any(binding.name == "pyrt" for binding in table.bindings):
        return
    if not any(isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
               and node.func.id == "frozenset" and getattr(node.func, "_binding", None) is None
               for node in ast.walk(tree)):
        return
    frozen_bindings: Set[int] = set()
    proven_reads: Set[int] = set()
    origins: Dict[int, ast.expr] = {}
    module_statements = {id(stmt) for stmt in tree.body}
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            proven_reads.update(_definitely_assigned_loads(fn))
    for stmt in ast.walk(tree):
        if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
            target, value = stmt.targets[0], stmt.value
        elif isinstance(stmt, ast.AnnAssign) and stmt.value is not None:
            target, value = stmt.target, stmt.value
        else:
            continue
        binding = getattr(target, "_binding", None) if isinstance(target, ast.Name) else None
        if binding is not None and not table.bindings[binding].rebound:
            if table.bindings[binding].scope != 0 or id(stmt) in module_statements:
                origins[binding] = value

    def literal_origin(node: ast.Name) -> Optional[ast.expr]:
        current: ast.expr = node
        seen: Set[int] = set()
        while isinstance(current, ast.Name):
            binding = getattr(current, "_binding", None)
            if binding is None or binding in seen or binding not in origins:
                return None
            seen.add(binding)
            value = origins[binding]
            if id(current) not in proven_reads and not (
                    table.bindings[binding].scope == 0
                    and (value.lineno, value.col_offset) < (current.lineno, current.col_offset)):
                return None
            current = value
        if isinstance(current, ast.Constant) and isinstance(current.value, float):
            return current
        if (isinstance(current, ast.UnaryOp) and isinstance(current.op, (ast.USub, ast.UAdd))
                and isinstance(current.operand, ast.Constant) and isinstance(current.operand.value, float)):
            return current
        return None

    def hashable_literal(node: ast.AST) -> bool:
        if isinstance(node, ast.Constant):
            return node.value is None or isinstance(node.value, (bool, int, float, str, bytes))
        if isinstance(node, ast.Tuple):
            return all(hashable_literal(item) for item in node.elts)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            return isinstance(node.operand, ast.Constant) and type(node.operand.value) in (int, float)
        return bool(getattr(node, "_frozen_literal", False))

    def literal_iterable(node: ast.AST) -> bool:
        if isinstance(node, ast.Constant):
            return isinstance(node.value, (str, bytes))
        if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
            return all(hashable_literal(item) for item in node.elts)
        return False

    def boxed(node: ast.expr) -> ast.expr:
        # Recover readonly float literals only through proven assignments.
        if isinstance(node, ast.Name):
            literal = literal_origin(node)
            if literal is not None:
                return boxed(copy.deepcopy(literal))
        if isinstance(node, ast.Constant) and isinstance(node.value, float):
            number = _runtime_call("to_float", [_runtime_call("box", [node], node)], node)
            return _runtime_call("box", [number], node)
        if (isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd))
                and isinstance(node.operand, ast.Constant) and isinstance(node.operand.value, float)):
            number = _runtime_call("to_float", [_runtime_call("box", [node.operand], node)], node)
            signed = ast.copy_location(ast.UnaryOp(op=node.op, operand=number), node)
            return _runtime_call("box", [signed], node)
        if isinstance(node, (ast.List, ast.Tuple, ast.Set)) and not any(
                isinstance(item, ast.Starred) for item in node.elts):
            items = ast.copy_location(ast.List(elts=[boxed(item) for item in node.elts],
                                               ctx=ast.Load()), node)
            packed = items if items.elts else _runtime_call(
                "elements", [_runtime_call("empty_list", [], node)], node)
            if isinstance(node, ast.Tuple):
                return _runtime_call("Value", [_runtime_call("new_tuple", [packed], node)], node)
            if isinstance(node, ast.Set):
                made = _runtime_call("new_set", [packed], node)
                made._api = "__pyrt__.new_set"
                return _runtime_call("Value", [made], node)
            return _runtime_call("box", [items], node)
        return _deep_box(node)

    class Lower(ast.NodeTransformer):
        def visit_Call(self, node: ast.Call) -> ast.AST:
            self.generic_visit(node)
            if not (isinstance(node.func, ast.Name) and node.func.id == "frozenset"
                    and getattr(node.func, "_binding", None) is None
                    and len(node.args) <= 1 and not node.keywords
                    and not any(isinstance(arg, ast.Starred) for arg in node.args)):
                return node
            iterable = node.args[0] if node.args else ast.copy_location(
                ast.List(elts=[], ctx=ast.Load()), node)
            literal = literal_iterable(iterable)
            result = _runtime_call("frozenset_from", [boxed(iterable)], node)
            result._api = "__pyrt__.frozenset_from"
            result._frozen_literal = literal
            return result

    Lower().visit(tree)
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Call) and getattr(
                node.value, "_api", "") == "__pyrt__.frozenset_from":
            frozen_bindings.update(getattr(target, "_binding", -1) for target in node.targets
                                   if isinstance(target, ast.Name))

    class Membership(ast.NodeTransformer):
        def visit_Compare(self, node: ast.Compare) -> ast.AST:
            self.generic_visit(node)
            if len(node.ops) != 1 or not isinstance(node.ops[0], (ast.In, ast.NotIn)):
                return node
            right = node.comparators[0]
            if not (isinstance(right, ast.Name) and getattr(right, "_binding", None) in frozen_bindings
                    or isinstance(right, ast.Call) and getattr(right, "_api", "") == "__pyrt__.frozenset_from"):
                return node
            call = _runtime_call("item_in", [boxed(node.left), right], node)
            call._api = "__pyrt__.item_in"
            if isinstance(node.ops[0], ast.NotIn):
                return ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=call), node)
            return call

    Membership().visit(tree)


def _lower_dynamic_values(tree: ast.Module, table: Optional[symbols.SymbolTable],
                          facts: Optional[infer.TypeFacts],
                          any_lists: Optional[set] = None) -> None:
    """Operations on a value whose type the code does not show go through the runtime.

    A parameter with no annotation, and whatever is computed from one, is emitted as the
    runtime's value (`Any`). V has no indexing, iteration, truth or equality for it, so
    `xs[0]` becomes `pyrt.item_at(xs, 0)`, `for x in xs` visits `pyrt.elements(xs)`, a
    truth test is `pyrt.truth(x)`, `a == b` is `pyrt.eq(a, b)`, `len(x)` is
    `pyrt.length(x)`, and an operand of known type beside a dynamic one is boxed.

    `any_lists` are the names declared as a list of runtime values: their items and the
    variable of a loop over one are dynamic, and a list or tuple appended to one is boxed
    (V's `<<` would add its elements instead)."""
    if table is None or facts is None:
        return
    if any(b.name == "pyrt" for b in table.bindings):
        return
    any_lists = any_lists or set()

    inferred_bindings = {b["id"]: b.get("inferred") for b in facts.bindings}

    def optional_dynamic_annotation(annotation: Optional[ast.expr]) -> bool:
        text = _unparse_expr(annotation).replace("typing.", "").replace(" ", "") if annotation else ""
        return text in ("Optional[Any]", "Any|None", "None|Any",
                        "Optional[object]", "object|None", "None|object")

    optional_functions = {fn._binding for fn in ast.walk(tree)
                          if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef))
                          and getattr(fn, "_binding", None) is not None
                          and not table.bindings[fn._binding].rebound
                          and optional_dynamic_annotation(fn.returns)}
    optional_bindings = set()
    optional_aliases: dict[int, set[int]] = {}
    for stmt in ast.walk(tree):
        if isinstance(stmt, ast.arg) and optional_dynamic_annotation(stmt.annotation):
            optional_bindings.add(getattr(stmt, "_binding", None))
        target = (stmt.targets[0] if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1
                  else stmt.target if isinstance(stmt, ast.AnnAssign) else None)
        binding = getattr(target, "_binding", None) if isinstance(target, ast.Name) else None
        if binding is None:
            continue
        if isinstance(stmt, ast.AnnAssign) and optional_dynamic_annotation(stmt.annotation):
            optional_bindings.add(binding)
        if isinstance(stmt.value, ast.Call) and isinstance(stmt.value.func, ast.Name):
            if getattr(stmt.value.func, "_binding", None) in optional_functions:
                optional_bindings.add(binding)
        elif isinstance(stmt.value, ast.Name):
            source = getattr(stmt.value, "_binding", None)
            if source is not None:
                optional_aliases.setdefault(source, set()).add(binding)
    optional_bindings.discard(None)
    pending = list(optional_bindings)
    while pending:
        for alias in optional_aliases.get(pending.pop(), ()):
            if alias not in optional_bindings:
                optional_bindings.add(alias)
                pending.append(alias)

    def optional_value(node: ast.AST) -> bool:
        return (isinstance(node, ast.Name) and getattr(node, "_binding", None) in optional_bindings
                or isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and getattr(node.func, "_binding", None) in optional_functions)

    def any_list_annotation(annotation: Optional[ast.AST], binding_id: Optional[int] = None) -> bool:
        if annotation is None:
            return False
        text = _unparse_expr(annotation).replace("typing.", "")
        if text in ("list", "List") and binding_id is not None:
            # The later bare-container pass gives these parameters their inferred element type.
            type_id = inferred_bindings.get(binding_id)
            if type_id is not None and _annotation_for_type(facts.types, type_id):
                return False
        return text in (
            "list", "List", "list[Any]", "List[Any]", "list[object]", "List[object]")

    # Functions and bindings declared as lists with no known element type.
    any_list_functions = set()
    any_list_parameters: Dict[int, List[bool]] = {}
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if any_list_annotation(fn.returns):
                any_list_functions.add(getattr(fn, "_binding", None))
            binding_id = getattr(fn, "_binding", None)
            flags = [any_list_annotation(a.annotation, getattr(a, "_binding", None))
                     for a in fn.args.args]
            if binding_id is not None and any(flags) and not table.bindings[binding_id].rebound:
                any_list_parameters[binding_id] = flags
            for arg in fn.args.posonlyargs + fn.args.args + fn.args.kwonlyargs:
                if any_list_annotation(arg.annotation, getattr(arg, "_binding", None)):
                    any_lists.add(getattr(arg, "_binding", None))
        elif isinstance(fn, ast.AnnAssign) and isinstance(fn.target, ast.Name):
            if any_list_annotation(fn.annotation):
                any_lists.add(getattr(fn.target, "_binding", None))
    any_lists.discard(None)
    any_list_functions.discard(None)

    def any_list(node: ast.AST) -> bool:
        if isinstance(node, ast.ListComp):
            return dynamic(node.elt)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            return getattr(node.func, "_binding", None) in any_list_functions
        if isinstance(node, ast.Call) and getattr(node, "_api", ""):
            # a runtime call declared as giving a list of runtime values
            return _runtime_api().get(node._api, {}).get("returns") == "list[Any]"
        return getattr(node, "_any_list", False) or (
            isinstance(node, ast.Name) and getattr(node, "_binding", None) in any_lists)
    # The bindings the backend declares as `Any`: parameters with no annotation (the
    # receiver and the parameters of `__init__`, which the backend types from the fields,
    # are not among them), then every local that is only ever given a dynamic value.
    dynamic_bindings = set()
    dynamic_returning = set()
    native_operators = {id(fn) for cls in ast.walk(tree) if isinstance(cls, ast.ClassDef)
                        for fn in cls.body if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef))
                        and _dunder_to_v_op(fn.name) in (
                            "+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">=")}
    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)) or fn.name == "__init__":
            continue
        positional = fn.args.posonlyargs + fn.args.args
        for position, arg in enumerate(positional + fn.args.kwonlyargs):
            # V types an unannotated operator operand as its receiver's class.
            untyped = ((arg.annotation is None and id(fn) not in native_operators)
                       or arg.annotation is not None and _unparse_expr(arg.annotation) in (
                           "Any", "object", "typing.Any"))
            if untyped and not (position == 0 and arg.arg in ("self", "cls")):
                binding_id = getattr(arg, "_binding", None)
                if binding_id is not None:
                    dynamic_bindings.add(binding_id)

    # A local declared `name: Any`, and its first value where that is None or a display.
    for node in ast.walk(tree):
        if (isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name)
                and _unparse_expr(node.annotation) in ("Any", "object", "typing.Any")):
            binding_id = getattr(node.target, "_binding", None)
            if binding_id is None or table.scopes[table.bindings[binding_id].scope].kind != "function":
                continue
            dynamic_bindings.add(binding_id)
            if node.value is not None and (_is_display(node.value) or (
                    isinstance(node.value, ast.Constant) and node.value.value is None)):
                node.value = _deep_box(node.value)

    # Functions of this file with no return annotation that return a value: the backend
    # declares their result as `Any`. Their parameters, by position, for call sites.
    dynamic_functions: Dict[int, List[bool]] = {}
    for fn in ast.walk(tree):
        if not isinstance(fn, ast.FunctionDef) or fn.name == "__init__" or fn.decorator_list:
            continue
        binding_id = getattr(fn, "_binding", None)
        if binding_id is None or table.bindings[binding_id].rebound:
            continue
        if table.scopes[table.bindings[binding_id].scope].kind != "module":
            continue
        if fn.args.vararg or fn.args.kwarg or fn.args.kwonlyargs or fn.args.posonlyargs:
            continue
        # Where the older return inference names a type, the backend declares that type.
        returns_value = ((fn.returns is None and not _is_void_function(fn)
                          and not _is_generator(fn) and _infer_return_type(fn) == "")
                         or fn.returns is not None and _unparse_expr(fn.returns) in (
                             "Any", "object", "typing.Any"))
        flags = [getattr(a, "_binding", None) in dynamic_bindings for a in fn.args.args]
        if returns_value or any(flags):
            dynamic_functions[binding_id] = flags
            if returns_value:
                dynamic_returning.add(binding_id)

    # A dict declared with values of no stated type (`dict`, `dict[str, Any]`): what a
    # subscript of it gives is a runtime value. Functions of this file returning one,
    # parameters declared as one, and names only ever given one.
    any_dict_texts = ("dict", "Dict", "dict[str, Any]", "Dict[str, Any]", "dict[str, object]")

    def any_dict_annotation(annotation: Optional[ast.AST]) -> bool:
        return annotation is not None and _unparse_expr(annotation).replace("typing.", "") in any_dict_texts

    any_dict_functions = set()
    any_dict_bindings = set()
    # which positional parameters of a function of this file are declared as such a dict
    any_dict_parameters: Dict[int, List[bool]] = {}
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if any_dict_annotation(fn.returns):
                any_dict_functions.add(getattr(fn, "_binding", None))
            flags = [any_dict_annotation(a.annotation) for a in fn.args.args]
            binding_id = getattr(fn, "_binding", None)
            if any(flags) and binding_id is not None and not table.bindings[binding_id].rebound:
                any_dict_parameters[binding_id] = flags
            for a in fn.args.posonlyargs + fn.args.args + fn.args.kwonlyargs:
                binding_id = getattr(a, "_binding", None)
                if (any_dict_annotation(a.annotation) and binding_id is not None
                        and not table.bindings[binding_id].rebound):
                    any_dict_bindings.add(binding_id)
    any_dict_functions.discard(None)

    def any_dict(node: ast.AST) -> bool:
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            return getattr(node.func, "_binding", None) in any_dict_functions
        return isinstance(node, ast.Name) and getattr(node, "_binding", None) in any_dict_bindings

    def any_dict_get(node: ast.AST) -> bool:
        """A string-keyed dictionary's get returns a runtime value, including None."""
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr == "get" and any_dict(node.func.value)
                and not node.keywords and len(node.args) in (1, 2)
                and not any(isinstance(a, ast.Starred) for a in node.args)):
            return False
        key_type = getattr(node.args[0], "_assumed", getattr(node.args[0], "_type", None))
        if key_type is None or facts.types[key_type]["k"] != "str":
            return False
        return len(node.args) == 1 or dynamic(node.args[1]) or boxable(node.args[1])

    # `a or b` and `a and b` used as conditions keep V's operators; used for their value,
    # with a value of unknown type first, the runtime chooses.
    tested_values = set()

    def mark_tested(node: ast.expr) -> None:
        tested_values.add(id(node))
        if isinstance(node, ast.BoolOp):
            for value in node.values:
                mark_tested(value)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            mark_tested(node.operand)

    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.While, ast.IfExp, ast.Assert)):
            mark_tested(node.test)
        elif isinstance(node, ast.comprehension):
            for condition in node.ifs:
                mark_tested(condition)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            mark_tested(node.operand)

    def runs_free(node: ast.AST) -> bool:
        # evaluating it early changes nothing: a constant, a name, a display of those
        if isinstance(node, (ast.Constant, ast.Name)):
            return True
        if isinstance(node, (ast.List, ast.Tuple)):
            return all(runs_free(e) for e in node.elts)
        if isinstance(node, ast.Dict):
            return all(k is not None and runs_free(k) for k in node.keys) and all(
                runs_free(v) for v in node.values)
        return isinstance(node, ast.Attribute) and runs_free(node.value)

    def chosen_value(node: ast.AST) -> bool:
        return (isinstance(node, ast.BoolOp) and id(node) not in tested_values
                and (all(isinstance(v, (ast.Name, ast.Constant)) for v in node.values[:-1])
                     or all(runs_free(v) for v in node.values[1:]))
                and dynamic(node.values[0])
                and all(dynamic(v) or boxable(v) for v in node.values))

    def dynamic_method_call(node: ast.AST) -> bool:
        """A method called on a value of unknown type: the runtime finds
        the method from what the value is when the call runs."""
        return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and not node.keywords
                and not getattr(node, "_api", "")
                and not any(isinstance(a, ast.Starred) for a in node.args)
                and dynamic(node.func.value))

    def choice_boxable(node: ast.AST) -> bool:
        # Native mutable references must keep their aliases. A fresh display
        # can be boxed when its contents are runtime values or immutable leaves.
        if dynamic(node):
            return True
        if _is_display(node):
            values = node.values if isinstance(node, ast.Dict) else node.elts
            return all(choice_boxable(value) for value in values)
        return _truth_kind(node, facts) in ("int", "float", "str", "bool", "none", "bytes")

    def dynamic(node: ast.AST) -> bool:
        if getattr(node, "_dynamic", False):
            return True
        if isinstance(node, ast.Name):
            return getattr(node, "_binding", None) in dynamic_bindings
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            binding_id = getattr(node.func, "_binding", None)
            return binding_id in dynamic_returning or binding_id in dynamic_bindings
        if (isinstance(node, ast.Call) and not isinstance(node.func, ast.Attribute)
                and not node.keywords and not any(isinstance(a, ast.Starred) for a in node.args)
                and dynamic(node.func)):
            return True
        if isinstance(node, ast.Attribute) and isinstance(node.ctx, ast.Load):
            return not getattr(node, "_api", "") and dynamic(node.value)
        if isinstance(node, ast.IfExp):
            branches = (node.body, node.orelse)
            return any(dynamic(b) for b in branches) and all(choice_boxable(b) for b in branches)
        if any_dict_get(node) or dynamic_method_call(node) or chosen_value(node):
            return True
        if isinstance(node, ast.Subscript) and not isinstance(node.slice, ast.Slice):
            return dynamic(node.value) or any_list(node.value) or any_dict(node.value)
        if isinstance(node, ast.Subscript) and node.slice.step is None:
            return dynamic(node.value)
        if isinstance(node, ast.BinOp) and isinstance(
                node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Mod)):
            return dynamic(node.left) or dynamic(node.right)
        return False

    for node in ast.walk(tree):
        if (isinstance(node, (ast.For, ast.comprehension)) and any_list(node.iter)
                and isinstance(node.target, ast.Name)):
            binding_id = getattr(node.target, "_binding", None)
            if binding_id is not None and len(table.bindings[binding_id].sites) == 1:
                dynamic_bindings.add(binding_id)

    # A local is dynamic when each of its bindings is a plain assignment of a dynamic value.
    assigned: Dict[int, List[ast.expr]] = {}
    other_sites = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            binding_id = getattr(node.targets[0], "_binding", None)
            if binding_id is not None:
                assigned.setdefault(binding_id, []).append(node.value)
    for binding in table.bindings:
        plain = len(assigned.get(binding.id, []))
        if binding.is_param or len(binding.sites) != plain:
            other_sites.add(binding.id)
    # The variable of a loop over a value of unknown type is one too.
    loop_targets = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.For, ast.comprehension)) and isinstance(node.target, ast.Name):
            binding_id = getattr(node.target, "_binding", None)
            if binding_id is not None and len(table.bindings[binding_id].sites) == 1:
                loop_targets.append((binding_id, node.iter))

    # Flat unpacking binds runtime values. Rebindings and nested/starred targets
    # need their own type/assignment analysis and keep their existing paths.
    unpackings = []
    for node in ast.walk(tree):
        target = (node.targets[0] if isinstance(node, ast.Assign) and len(node.targets) == 1
                  else node.target if isinstance(node, ast.For) else None)
        if not isinstance(target, (ast.Tuple, ast.List)) or not target.elts:
            continue
        bindings = [getattr(e, "_binding", None) for e in target.elts]
        if (all(isinstance(e, ast.Name) for e in target.elts)
                and all(e.id == "_" or b is not None and len(table.bindings[b].sites) == 1
                        for e, b in zip(target.elts, bindings))):
            unpackings.append((node, [b for e, b in zip(target.elts, bindings) if e.id != "_"]))
    def boxable(node: ast.AST) -> bool:
        # a value of a known plain type, None, or a display: the runtime value of it is made
        if _is_display(node) or isinstance(node, ast.Constant) and node.value is None:
            return True
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        return type_id is not None and facts.types[type_id]["k"] in ("int", "float", "str", "bool")

    while True:
        # every value dynamic, or at least one and the others of a plain type (boxed where
        # they are assigned)
        grown = {b for b, values in assigned.items()
                 if b not in dynamic_bindings and b not in other_sites
                 and any(dynamic(v) for v in values)
                 and all(dynamic(v) or boxable(v) for v in values)}
        grown |= {b for b, iterable in loop_targets
                  if b not in dynamic_bindings and (dynamic(iterable) or any_list(iterable))}
        for node, bindings in unpackings:
            source = node.iter if isinstance(node, ast.For) else node.value
            if dynamic(source) or isinstance(node, ast.For) and any_list(source):
                grown |= set(bindings) - dynamic_bindings
        lists = {b for b, values in assigned.items()
                 if b not in other_sites and all(any_list(v) for v in values)} - any_lists
        dicts = {b for b, values in assigned.items()
                 if b not in other_sites and all(any_dict(v) for v in values)} - any_dict_bindings
        if not (grown or lists or dicts):
            break
        dynamic_bindings |= grown
        any_lists |= lists
        any_dict_bindings |= dicts

    # A name given only list comprehensions that collect values of unknown type is a list
    # of runtime values.
    any_lists |= {b for b, values in assigned.items()
                  if b not in other_sites and values
                  and all(isinstance(v, ast.ListComp) and dynamic(v.elt) for v in values)}

    _declare_block_locals(tree, table, facts, dynamic_bindings)

    def known(node: ast.AST) -> bool:
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        return (type_id is not None and facts.types[type_id]["k"] in (
            "int", "float", "str", "bool", "list", "dict", "none")) or runtime_instance(node)

    def runtime_instance(node: ast.AST) -> bool:
        named = getattr(node, "_api_returns", "")
        if isinstance(node, ast.Name):
            named = getattr(tree, "_runtime_binding_types", {}).get(
                getattr(node, "_binding", None), named)
        if _runtime_api().get(named, {}).get("dynamic_attributes", False):
            return True
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is None:
            return False
        typ = facts.types[type_id]
        return typ["k"] == "instance" and _runtime_api().get(
            typ.get("name", ""), {}).get("dynamic_attributes", False)

    def boxed(node: ast.expr) -> ast.expr:
        return _runtime_call("box", [node], node) if known(node) else node

    def container(node: ast.AST) -> bool:
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        return (type_id is not None and facts.types[type_id]["k"] == "list") or runtime_instance(node)

    def sequence(node: ast.AST) -> bool:
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        return isinstance(node, (ast.List, ast.Tuple, ast.ListComp)) or (
            type_id is not None and facts.types[type_id]["k"] in ("list", "tuple", "tuple_of"))

    def runtime_result(node: ast.AST) -> bool:
        return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and isinstance(node.func.value, ast.Name) and node.func.value.id == "pyrt")

    def fresh_boxable(node: ast.expr) -> bool:
        # Boxing a native mutable container copies it. Only new displays, immutable leaves,
        # and existing runtime handles can cross this boundary without losing an alias.
        if dynamic(node) or runtime_instance(node):
            return True
        if _is_display(node):
            values = node.values if isinstance(node, ast.Dict) else node.elts
            return all(fresh_boxable(value) for value in values)
        return isinstance(node, ast.Constant) or _truth_kind(node, facts) in (
            "int", "float", "str", "bool", "none", "bytes")

    called_attributes = {id(n.func) for n in ast.walk(tree)
                         if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)}
    unpack_nodes = {id(node) for node, _ in unpackings
                    if dynamic(node.iter if isinstance(node, ast.For) else node.value)
                    or isinstance(node, ast.For) and any_list(node.iter)}
    reserved_names = {b.name for b in table.bindings}

    def unpack(value: ast.expr, target: ast.expr) -> ast.expr:
        count = ast.copy_location(ast.Constant(value=len(target.elts)), target)
        call = _runtime_call("unpack", [value, count], value)
        call._api = "__pyrt__.unpack"
        return call

    class Lower(ast.NodeTransformer):
        def visit_IfExp(self, node: ast.IfExp) -> ast.AST:
            was_dynamic = dynamic(node)
            self.generic_visit(node)
            if was_dynamic:
                node.body = node.body if dynamic(node.body) else _deep_box(node.body)
                node.orelse = node.orelse if dynamic(node.orelse) else _deep_box(node.orelse)
                node._dynamic = True
            return node

        def visit_UnaryOp(self, node: ast.UnaryOp) -> ast.AST:
            self.generic_visit(node)
            if isinstance(node.op, ast.Not):
                node.operand = truth(node.operand)
            return node

        def visit_Attribute(self, node: ast.Attribute) -> ast.AST:
            self.generic_visit(node)
            if (isinstance(node.ctx, ast.Load) and id(node) not in called_attributes
                    and dynamic(node.value) and not getattr(node, "_api", "")):
                name = ast.copy_location(ast.Constant(value=node.attr), node)
                call = _runtime_call("getattr", [node.value, name], node)
                call._api = "builtins.getattr"
                return call
            return node

        def visit_Subscript(self, node: ast.Subscript) -> ast.AST:
            self.generic_visit(node)
            if (isinstance(node.ctx, ast.Load) and dynamic(node.value)
                    and not isinstance(node.slice, ast.Slice)):
                return _runtime_call("item_at", [node.value, boxed(node.slice)], node)
            if (isinstance(node.ctx, ast.Load) and dynamic(node.value)
                    and node.slice.step is None):
                nothing = ast.copy_location(ast.Constant(value=None), node)
                bounds = [_runtime_call("box", [bound if bound is not None else nothing], node)
                          for bound in (node.slice.lower, node.slice.upper)]
                return _runtime_call("slice_of", [node.value] + bounds, node)
            return node

        def visit_Assign(self, node: ast.Assign) -> ast.AST:
            # `v[key] = item` where v is a value of unknown type
            target = node.targets[0] if len(node.targets) == 1 else None
            stores = (isinstance(target, ast.Subscript) and not isinstance(target.slice, ast.Slice)
                      and dynamic(target.value))
            self.generic_visit(node)
            if id(node) in unpack_nodes:
                node.value = unpack(node.value, target)
            if (target is not None and isinstance(target, ast.Name)
                    and getattr(target, "_binding", None) in dynamic_bindings
                    and not dynamic(node.value) and boxable(node.value)):
                # a plain value given to a name that holds values of unknown type
                node.value = _deep_box(node.value)
            if not stores:
                return node
            item = node.value
            if not dynamic(item):
                item = _deep_box(item) if _is_display(item) else boxed(item)
            call = _runtime_call("set_index", [target.value, boxed(target.slice), item], node)
            return ast.copy_location(ast.Expr(value=call), node)

        def visit_BinOp(self, node: ast.BinOp) -> ast.AST:
            was_dynamic = dynamic(node)
            self.generic_visit(node)
            if isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Mod)):
                if dynamic(node.left) and known(node.right):
                    node.right = boxed(node.right)
                    node._dynamic = True
                elif dynamic(node.right) and known(node.left):
                    node.left = boxed(node.left)
                    node._dynamic = True
            if was_dynamic:
                node._dynamic = True
            arithmetic = {ast.Add: "plus", ast.Sub: "minus", ast.Mult: "times",
                          ast.Div: "over", ast.Mod: "modulo"}.get(type(node.op))
            if (arithmetic and getattr(node, "_dynamic", False)
                    and (runtime_result(node.left) or runtime_result(node.right))
                    and all(dynamic(side) for side in (node.left, node.right))):
                # what a runtime call gives is not the file's `Any`, whose operators V
                # would use: the runtime does the arithmetic
                return _runtime_call(arithmetic, [node.left, node.right], node)
            return node

        def visit_BoolOp(self, node: ast.BoolOp) -> ast.AST:
            chosen = chosen_value(node)
            lazy = all(isinstance(v, (ast.Name, ast.Constant)) for v in node.values[:-1])
            self.generic_visit(node)
            if not chosen:
                return node
            if lazy:
                result = node.values[-1]
                if not dynamic(result):
                    result = _deep_box(result)
                for value in reversed(node.values[:-1]):
                    selected = value if dynamic(value) else _deep_box(value)
                    test = _runtime_call("truth", [selected], value)
                    if isinstance(node.op, ast.Or):
                        result = ast.IfExp(test=test, body=copy.deepcopy(selected), orelse=result)
                    else:
                        result = ast.IfExp(test=test, body=result, orelse=copy.deepcopy(selected))
                    ast.copy_location(result, node)
                    result._dynamic = True
                return result
            name = "either" if isinstance(node.op, ast.Or) else "both"
            result = node.values[0]
            for value in node.values[1:]:
                other = value if dynamic(value) else _deep_box(value)
                result = _runtime_call(name, [result, other], node)
            return result

        def visit_Compare(self, node: ast.Compare) -> ast.AST:
            self.generic_visit(node)
            if len(node.ops) != 1:
                return node
            left, right = node.left, node.comparators[0]
            if not (dynamic(left) or dynamic(right)):
                return node
            if isinstance(node.ops[0], (ast.Is, ast.IsNot)):
                value = (left if isinstance(right, ast.Constant) and right.value is None
                         else right if isinstance(left, ast.Constant) and left.value is None
                         else None)
                if value is not None:
                    call = _runtime_call("is_none", [value], node)
                    if isinstance(node.ops[0], ast.IsNot):
                        return ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=call), node)
                    return call
            if isinstance(node.ops[0], (ast.Eq, ast.NotEq)):
                call = _runtime_call("eq", [boxed(left), boxed(right)], node)
                if isinstance(node.ops[0], ast.NotEq):
                    return ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=call), node)
                return call
            if isinstance(node.ops[0], (ast.In, ast.NotIn)):
                call = _runtime_call("has", [boxed(right), boxed(left)], node)
                call._dynamic = False
                if isinstance(node.ops[0], ast.NotIn):
                    return ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=call), node)
                return call
            if isinstance(node.ops[0], (ast.Lt, ast.LtE, ast.Gt, ast.GtE)):
                node.left = boxed(left)
                node.comparators = [boxed(right)]
            return node

        def visit_Call(self, node: ast.Call) -> ast.AST:
            is_method = dynamic_method_call(node)
            is_dict_get = any_dict_get(node)
            is_value_join = (isinstance(node.func, ast.Attribute) and node.func.attr == "join"
                             and len(node.args) == 1 and not node.keywords
                             and not isinstance(node.args[0], ast.Starred)
                             and _truth_kind(node.func.value, facts) == "str"
                             and (dynamic(node.args[0]) or any_list(node.args[0])
                                  or _truth_kind(node.args[0], facts) == "str"))
            join_plain = is_value_join and not dynamic(node.args[0])
            is_callable = (not isinstance(node.func, ast.Attribute) and dynamic(node.func)
                           and not node.keywords and not any(isinstance(a, ast.Starred) for a in node.args))
            self.generic_visit(node)
            if is_value_join and isinstance(node.func, ast.Attribute):
                iterable = (_runtime_call("box", [node.args[0]], node)
                            if join_plain else node.args[0])
                call = _runtime_call("join", [boxed(node.func.value), iterable], node)
                call._api = "__pyrt__.join"
                result = _runtime_call("to_str", [call], node)
                result._dynamic = False
                for name in ("_type", "_assumed"):
                    if hasattr(node, name):
                        setattr(result, name, getattr(node, name))
                return result
            if is_dict_get and isinstance(node.func, ast.Attribute):
                default = node.args[1] if len(node.args) == 2 else ast.copy_location(
                    ast.Constant(value=None), node)
                return _runtime_call("map_get", [node.func.value, node.args[0],
                                                 _deep_box(default)], node)
            if is_callable:
                args = [a if dynamic(a) or not fresh_boxable(a)
                        else _runtime_call("box", [a], a) for a in node.args]
                arguments = ast.copy_location(ast.List(elts=args, ctx=ast.Load()), node)
                call = _runtime_call("call", [node.func, arguments], node)
                call._api = "__pyrt__.call"
                return call
            if is_method:
                name = ast.copy_location(ast.Constant(value=node.func.attr), node)
                args = [a if dynamic(a) else _runtime_call("box", [a], a) for a in node.args]
                if node.func.attr not in _builtin_method_names():
                    args = [a if dynamic(a) or not fresh_boxable(a)
                            else _runtime_call("box", [a], a) for a in node.args]
                    method = _runtime_call("getattr", [node.func.value, name], node)
                    method._api = "builtins.getattr"
                    arguments = ast.copy_location(ast.List(elts=args, ctx=ast.Load()), node)
                    call = _runtime_call("call", [method, arguments], node)
                    call._api = "__pyrt__.call"
                    return call
                call = _runtime_call("invoke", [node.func.value, name] + args, node)
                call._invoked = True
                return call
            if isinstance(node.func, ast.Name) and not node.keywords:
                list_flags = any_list_parameters.get(getattr(node.func, "_binding", None), [])
                for flag, arg in zip(list_flags, node.args):
                    if flag and isinstance(arg, ast.List):
                        arg.elts = [_deep_box(e) if _is_display(e) and fresh_boxable(e)
                                    else e for e in arg.elts]
                holds_values = any_dict_parameters.get(getattr(node.func, "_binding", None), [])
                for flag, arg in zip(holds_values, node.args):
                    if flag and isinstance(arg, ast.Dict) and _is_display(arg):
                        # the dict holds runtime values: a display inside it is one too
                        arg.values = [_deep_box(v) if _is_display(v) else v for v in arg.values]
                flags = dynamic_functions.get(getattr(node.func, "_binding", None))
                if flags is not None and len(node.args) <= len(flags):
                    # A list or dict has no automatic conversion to the runtime value
                    node.args = [_deep_box(a) if flags[i] and (_is_display(a) or (
                                     isinstance(a, ast.Constant) and a.value is None))
                                 else boxed(a) if flags[i] and container(a) else a
                                 for i, a in enumerate(node.args)]
                if (node.func.id == "print" and getattr(node.func, "_binding", None) is None):
                    node.args = [_runtime_call("str", [a], a) if dynamic(a) else a
                                 for a in node.args]
                    node.args = [_runtime_call("str", [_runtime_call("box", [a], a)], a)
                                 if any_list(a) else a for a in node.args]
            if (isinstance(node.func, ast.Attribute) and node.func.attr == "append"
                    and any_list(node.func.value) and len(node.args) == 1
                    and not node.keywords and sequence(node.args[0])
                    and not dynamic(node.args[0])):
                node.args = [_runtime_call("box", [node.args[0]], node.args[0])]
            if (isinstance(node.func, ast.Name) and node.func.id == "len"
                    and getattr(node.func, "_binding", None) is None
                    and len(node.args) == 1 and not node.keywords and dynamic(node.args[0])):
                return _runtime_call("length", [node.args[0]], node)
            if (isinstance(node.func, ast.Name) and node.func.id == "str"
                    and getattr(node.func, "_binding", None) is None
                    and len(node.args) == 1 and not node.keywords and dynamic(node.args[0])):
                # `str(x)` of a runtime value is Python's text of it, not V's
                return _runtime_call("str", [node.args[0]], node)
            if (isinstance(node.func, ast.Name) and node.func.id == "bool"
                    and getattr(node.func, "_binding", None) is None
                    and len(node.args) == 1 and not node.keywords and dynamic(node.args[0])):
                return _runtime_call("truth", [node.args[0]], node)
            return node

        def visit_For(self, node: ast.For) -> ast.AST:
            self.generic_visit(node)
            if dynamic(node.iter):
                node.iter = _runtime_call("elements", [node.iter], node.iter)
            if id(node) in unpack_nodes:
                number = 0
                while f"py2v_dynamic_iter_{number}" in reserved_names:
                    number += 1
                name = f"py2v_dynamic_iter_{number}"
                reserved_names.add(name)
                item = ast.copy_location(ast.Name(id=name, ctx=ast.Load()), node.target)
                item._dynamic = True
                assignment = ast.copy_location(
                    ast.Assign(targets=[node.target], value=unpack(item, node.target)), node.target)
                node.target = ast.copy_location(ast.Name(id=name, ctx=ast.Store()), node.target)
                node.body.insert(0, assignment)
            return node

        def visit_comprehension(self, node: ast.comprehension) -> ast.AST:
            self.generic_visit(node)
            if dynamic(node.iter):
                node.iter = _runtime_call("elements", [node.iter], node.iter)
                node.iter._dynamic = False
            return node

    def truth(node: ast.expr) -> ast.expr:
        if isinstance(node, ast.BoolOp):
            node.values = [truth(v) for v in node.values]
            return node
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            node.operand = truth(node.operand)
            return node
        represented = getattr(node, "_represented", None)
        storage_dynamic = (represented is not None
                           and facts.types[represented]["k"] == "dynamic"
                           and not any(isinstance(n, ast.Name)
                                       and getattr(n, "_binding", None) in native_maps
                                       for n in ast.walk(node)))
        if optional_value(node):
            return _runtime_call("truth_option", [node], node)
        if dynamic(node) or storage_dynamic:
            return _runtime_call("truth", [node], node)
        return node

    # Truth tests first: they look at names and subscripts as written.
    context = AnalysisContext(table=table, facts=facts)
    native_maps = {getattr(n.target, "_binding", None) for n in ast.walk(tree)
                   if isinstance(n, ast.AnnAssign) and context.native_map_annotation(n)}
    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.While, ast.IfExp, ast.Assert)):
            if not any(isinstance(n, ast.NamedExpr) for n in ast.walk(node.test)):
                node.test = truth(node.test)
        elif isinstance(node, ast.comprehension):
            node.ifs = [test if any(isinstance(n, ast.NamedExpr) for n in ast.walk(test))
                        else truth(test) for test in node.ifs]
    try:
        Lower().visit(tree)
    except RecursionError:
        # An expression nested hundreds deep (a sum of 400 terms): left as written.
        pass

    # A value of unknown type returned from a function declared as returning a plain type
    # is converted there, with Python's TypeError if it is something else.
    converters = {"int": "to_int", "float": "to_float", "str": "to_str", "bool": "to_bool"}

    def own_returns(fn: ast.AST) -> List[ast.Return]:
        found: List[ast.Return] = []
        pending = list(ast.iter_child_nodes(fn))
        while pending:
            node = pending.pop()
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef)):
                continue
            if isinstance(node, ast.Return):
                found.append(node)
            pending.extend(ast.iter_child_nodes(node))
        return found

    # A list or dict written out, returned from a function whose result is a value of
    # unknown type, is that value: V makes one of a number or text by itself, not of these.
    for fn in ast.walk(tree):
        if isinstance(fn, ast.FunctionDef) and getattr(fn, "_binding", None) in dynamic_returning:
            for ret in own_returns(fn):
                if (fn.returns is not None and _unparse_expr(fn.returns) in (
                        "Any", "object", "typing.Any") and ret.value is not None
                        and not fresh_boxable(ret.value)):
                    continue
                if ret.value is not None and (_is_display(ret.value) or (
                        isinstance(ret.value, ast.Constant) and ret.value.value is None)):
                    ret.value = _deep_box(ret.value)

    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)) or fn.returns is None:
            continue
        convert = converters.get(_unparse_expr(fn.returns), "")
        if not convert:
            continue
        for ret in own_returns(fn):
            if ret.value is not None and getattr(ret.value, "_dynamic", False):
                ret.value = _runtime_call(convert, [ret.value], ret.value)
                ret.value._dynamic = False


def _constant_display(node: ast.AST, constants: set) -> bool:
    """Whether a value is built only from literals and names of module constants."""
    if getattr(node, "_frozen_literal", False):
        return True
    if isinstance(node, ast.Constant):
        return not isinstance(node.value, (bytes, complex)) and node.value is not Ellipsis
    if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
        return bool(node.elts) and all(_constant_display(e, constants) for e in node.elts)
    if isinstance(node, ast.Dict):
        return bool(node.keys) and all(
            k is not None and _constant_display(k, constants) for k in node.keys) and all(
            _constant_display(v, constants) for v in node.values)
    if isinstance(node, ast.UnaryOp):
        return _constant_display(node.operand, constants)
    if isinstance(node, ast.BinOp):
        return _constant_display(node.left, constants) and _constant_display(node.right, constants)
    if isinstance(node, ast.Name):
        return getattr(node, "_binding", None) in constants or node.id == "__name__"
    if isinstance(node, ast.Call) and getattr(node, "_api", "") and not node.keywords:
        # a runtime library object made once from constants: `logging.getLogger(__name__)`
        return all(_constant_display(a, constants) for a in node.args)
    return False


def _v_spelling(name: str) -> str:
    return name.strip("_").lower()


def _plan_error_propagation(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """Decide which functions return a V result, which calls pass their error on, and
    which `try` statements run their handlers.

    Stages 1 to 3 of the exception design, for straight-line code and `try` without
    `finally`. A call "can fail" when the runtime manifest says so, or when it calls by
    name a function of this file that this pass made fallible.

    - Outside every `try`, in a module-level function (not a method, generator, decorated
      function, or `main`): the function becomes fallible. The backend emits its body as
      `<name>_py` returning a result, each such call with `!`, and keeps the old name as a
      wrapper that ends the program on an error, for callers this pass does not see.
    - Inside the body of a `try` that has handlers and no `finally`: the call is guarded.
      The backend puts the body in a one-shot loop, leaves it at the first failing call,
      and then runs the handler whose classes match (`pyrt.caught`), else the `else`
      block. An error no handler takes is passed on where the function is fallible and
      ends the program elsewhere. A `try` whose body has its own `break` or `continue`,
      or no call that can fail, is left as it was.

    Comprehensions, lambdas and nested functions are not looked into."""
    if table is None:
        return
    api = _runtime_api()
    candidates: Dict[int, ast.FunctionDef] = {}
    # Preserve a source function when its generated result helper would collide.
    existing_functions = {_v_spelling(s.name) for s in tree.body
                          if isinstance(s, ast.FunctionDef)}
    for stmt in tree.body:
        if not isinstance(stmt, ast.FunctionDef) or stmt.name == "main" or stmt.decorator_list:
            continue
        if stmt.args.vararg or stmt.args.kwarg or _is_generator(stmt):
            continue
        if stmt.returns is not None:
            declared = _unparse_expr(stmt.returns).replace("typing.", "")
            if declared.startswith("Optional[") or (
                    "|" in declared and "None" in [p.strip() for p in declared.split("|")]):
                # V has no result of an option (vk:no-result-of-option): such a function
                # keeps ending the program on an error until results carry a Maybe
                continue
        if _v_spelling(stmt.name) + "_py" in existing_functions:
            continue
        binding_id = getattr(stmt, "_binding", None)
        if binding_id is None or table.bindings[binding_id].rebound:
            continue
        candidates[binding_id] = stmt

    closed = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef,
              ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)
    loops = (ast.For, ast.AsyncFor, ast.While)

    def leaves_loop(stmts: List[ast.stmt]) -> bool:
        """Whether the statements hold a `break` or `continue` of an enclosing loop."""
        pending = list(stmts)
        while pending:
            node = pending.pop()
            if isinstance(node, (ast.Break, ast.Continue)):
                return True
            if isinstance(node, closed) or isinstance(node, loops):
                continue
            pending.extend(ast.iter_child_nodes(node))
        return False

    def lowerable(node: ast.AST) -> bool:
        return (isinstance(node, ast.Try) and bool(node.handlers) and not node.finalbody
                and not leaves_loop(node.body))

    builtin_exceptions = _builtin_exception_names()
    local_classes = {c.name: [_unparse_expr(b) for b in c.bases]
                     for c in tree.body if isinstance(c, ast.ClassDef)}

    def exception_bases(name: str) -> Optional[List[str]]:
        """The bases of a class of this file down to the builtin ones, or None when the
        name is not an exception class this pass can vouch for."""
        if name in builtin_exceptions:
            return []
        if name not in local_classes:
            return None
        chain: List[str] = []
        pending = list(local_classes[name])
        seen = {name}
        while pending:
            base = pending.pop(0)
            if base in seen:
                continue
            seen.add(base)
            if base in builtin_exceptions:
                chain.append(base)
            elif base in local_classes:
                chain.append(base)
                pending.extend(local_classes[base])
            else:
                return None
        return chain if any(b in builtin_exceptions for b in chain) else None

    def raised_class(node: ast.Raise) -> str:
        """The class a `raise C(...)` or `raise C` names, when it is one this pass knows."""
        exc = node.exc
        if isinstance(exc, ast.Call) and not exc.keywords and not any(
                isinstance(a, ast.Starred) for a in exc.args):
            exc = exc.func
        if isinstance(exc, ast.Name) and exception_bases(exc.id) is not None:
            return exc.id
        return ""

    def calls_in(stmts: List[ast.stmt], into_try_bodies: bool) -> List[ast.AST]:
        """The calls and `raise` statements of straight-line code. A lowerable `try`
        contributes its handlers and `else` (they run as the function's own code); its
        body only when asked."""
        found: List[ast.AST] = []

        def walk(node: ast.AST) -> None:
            if isinstance(node, closed):
                return
            if isinstance(node, ast.Try) or type(node).__name__ == "TryStar":
                if not lowerable(node):
                    return
                if into_try_bodies:
                    for child in node.body:
                        walk(child)
                for handler in node.handlers:
                    for child in handler.body:
                        walk(child)
                for child in node.orelse:
                    walk(child)
                return
            if isinstance(node, (ast.Call, ast.Raise)):
                found.append(node)
            for child in ast.iter_child_nodes(node):
                walk(child)

        for stmt in stmts:
            walk(stmt)
        return found

    def body_calls(node: ast.Try) -> List[ast.AST]:
        """The calls and raises of a try body that belong to this `try` (not to one nested
        in it)."""
        found: List[ast.AST] = []

        def walk(child: ast.AST) -> None:
            if isinstance(child, closed) or isinstance(child, ast.Try) \
                    or type(child).__name__ == "TryStar":
                return
            if isinstance(child, (ast.Call, ast.Raise)):
                found.append(child)
            for inner in ast.iter_child_nodes(child):
                walk(inner)

        for stmt in node.body:
            walk(stmt)
        return found

    def handler_classes(handler: ast.ExceptHandler) -> Optional[List[str]]:
        """The class names a handler takes, as the runtime knows them; [] for a bare
        `except`; None when a class is not a plain name."""
        if handler.type is None:
            return []
        parts = handler.type.elts if isinstance(handler.type, ast.Tuple) else [handler.type]
        names: List[str] = []
        for part in parts:
            text = _unparse_expr(part)
            if not all(piece.isidentifier() for piece in text.split(".")):
                return None
            names.append("JSONDecodeError" if text == "json.JSONDecodeError" else text)
        return names

    def takes_every_exception(node: ast.Try) -> bool:
        for handler in node.handlers:
            classes = handler_classes(handler)
            if classes == [] or (classes and ("Exception" in classes or "BaseException" in classes)):
                return True
        return False

    fallible: Set[int] = set()

    def can_fail(call: ast.AST) -> bool:
        if isinstance(call, ast.Raise):
            # a bare `raise` is planned with the handler it stands in
            return call.exc is not None and raised_class(call) != ""
        api_name = getattr(call, "_api", "")
        entry = api.get(api_name) or api.get("__pyrt__." + api_name)
        if entry and entry.get("raises"):
            return True
        return isinstance(call.func, ast.Name) and getattr(call.func, "_binding", None) in fallible

    def tries_of(stmts: List[ast.stmt]) -> List[ast.Try]:
        found: List[ast.Try] = []
        pending = list(stmts)
        while pending:
            node = pending.pop()
            if isinstance(node, closed):
                continue
            if lowerable(node):
                found.append(node)
            pending.extend(ast.iter_child_nodes(node))
        return found

    def needs_result(fn: ast.FunctionDef) -> bool:
        if any(can_fail(c) for c in calls_in(fn.body, False)):
            return True
        # a guarded failure that no handler of its `try` is sure to take leaves the function
        for t in tries_of(fn.body):
            if not any(can_fail(c) for c in body_calls(t)):
                continue
            if not takes_every_exception(t):
                return True
            if any(isinstance(c, ast.Raise) and c.exc is None
                   for h in t.handlers for c in calls_in(h.body, False)):
                return True
        return False

    while True:
        grown = {b for b, fn in candidates.items() if b not in fallible and needs_result(fn)}
        if not grown:
            break
        fallible |= grown

    counter = 0
    for scope in [tree] + [n for n in ast.walk(tree)
                           if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]:
        own = scope.body
        for node in tries_of(own):
            guarded = [c for c in body_calls(node) if can_fail(c)]
            classes = [handler_classes(h) for h in node.handlers]
            if not guarded or any(c is None for c in classes):
                continue
            if getattr(node, "_guard", 0):
                continue  # reached again through an enclosing scope's walk
            counter += 1
            node._guard = counter
            for call in guarded:
                call._guard = counter
                if isinstance(call, ast.Raise):
                    call._mode = "guard"
                    call._bases = exception_bases(raised_class(call))
            for handler, names in zip(node.handlers, classes):
                handler._classes = names
                # a bare `raise` in the handler's own code passes the caught error on
                for inner in calls_in(handler.body, False):
                    if isinstance(inner, ast.Raise) and inner.exc is None:
                        inner._mode = "reraise"
                        inner._guard = counter
    for binding_id in fallible:
        fn = candidates[binding_id]
        fn._raises = True
        for call in calls_in(fn.body, False):
            if can_fail(call) and not getattr(call, "_guard", 0):
                if isinstance(call, ast.Raise):
                    call._mode = "result"
                    call._bases = exception_bases(raised_class(call))
                else:
                    call._propagate = True


@functools.lru_cache(maxsize=None)
def _builtin_method_names() -> frozenset:
    """The public methods of the builtin types a value of unknown type can be."""
    return frozenset(name for kind in (str, list, dict, set, tuple, bytes)
                     for name in dir(kind) if not name.startswith("_"))


def _builtin_exception_names() -> frozenset:
    """The builtin exception classes, as Python itself lists them."""
    import builtins
    return frozenset(name for name, value in vars(builtins).items()
                     if isinstance(value, type) and issubclass(value, BaseException))


def _mark_module_constants(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """Name the module-level values that functions read, so they become V constants.

    A V function cannot see a local of `main`. A name bound once at module level to a
    literal value, and read inside a function, is declared as a module constant instead.
    A name that another scope also binds stays where it was: V refuses a local that
    repeats a constant's name.
    """
    if table is None:
        return
    read_in_function: set = set()
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            for node in ast.walk(fn):
                if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load):
                    read_in_function.add(getattr(node, "_binding", None))
    spellings: Dict[str, int] = {}
    for b in table.bindings:
        key = _v_spelling(b.name)
        spellings[key] = spellings.get(key, 0) + 1
    constants: set = set()
    names: List[str] = []
    for stmt in tree.body:
        if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
            target, value = stmt.targets[0], stmt.value
        elif isinstance(stmt, ast.AnnAssign) and stmt.value is not None:
            target, value = stmt.target, stmt.value
        else:
            continue
        if not isinstance(target, ast.Name):
            continue
        binding_id = getattr(target, "_binding", None)
        if binding_id is None or binding_id not in read_in_function:
            continue
        b = table.bindings[binding_id]
        if b.scope != 0 or b.rebound or b.declared_global or spellings.get(_v_spelling(b.name), 0) != 1:
            continue
        if not _constant_display(value, constants):
            continue
        constants.add(binding_id)
        names.append(target.id)
    tree._module_consts = names


def _is_display(node: ast.AST) -> bool:
    """A dict or list written out, with no `**` or `*` part."""
    if isinstance(node, ast.Dict):
        return all(k is not None for k in node.keys)
    return (isinstance(node, ast.List) and isinstance(node.ctx, ast.Load)
            and not any(isinstance(e, ast.Starred) for e in node.elts))


def _deep_box(node: ast.expr) -> ast.expr:
    """The runtime value of an expression. A display inside a boxed display is boxed at
    every level: the runtime value of a dict holds runtime values, not V maps."""
    if getattr(node, "_dynamic", False):
        return node
    if isinstance(node, ast.Constant) and isinstance(node.value, float):
        number = _runtime_call("to_float", [_runtime_call("box", [node], node)], node)
        return _runtime_call("box", [number], node)
    if (isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd))
            and isinstance(node.operand, ast.Constant) and isinstance(node.operand.value, float)):
        number = _runtime_call("to_float", [_runtime_call("box", [node.operand], node)], node)
        signed = ast.copy_location(ast.UnaryOp(op=node.op, operand=number), node)
        return _runtime_call("box", [signed], node)
    if _is_display(node):
        if isinstance(node, ast.Dict):
            node.values = [_deep_box(v) for v in node.values]
        else:
            node.elts = [_deep_box(e) for e in node.elts]  # type: ignore[attr-defined]
    return _runtime_call("box", [node], node)


def _box_mixed_displays(tree: ast.Module, table: Optional[symbols.SymbolTable],
                        facts: Optional[infer.TypeFacts]) -> None:
    """A list or dict display whose values are not all of one type holds runtime values:
    `["a", 1.5, 2]` becomes a list of `pyrt.box(...)` of each, as a V array has one element
    type (vk:mixed-array-needs-a-sum-type). A display of one type is left as written."""
    if table is None or facts is None or any(b.name == "pyrt" for b in table.bindings):
        return

    def kind(node: ast.expr) -> str:
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        if type_id is None:
            return "?"
        entry = facts.types[type_id]
        # The kind alone: two lists count as one type here, whatever their elements (an
        # empty list beside a list of ints, or lists of mixed numbers, are left to V).
        return entry["k"] if entry["k"] not in ("unknown", "dynamic", "union") else "?"

    def mixed(values: List[ast.expr]) -> bool:
        if len(values) < 2 or any(isinstance(v, ast.Starred) or v is None for v in values):
            return False
        kinds = {kind(v) for v in values}
        if any(getattr(v, "_dynamic", False) for v in values) and not all(
                getattr(v, "_dynamic", False) for v in values):
            # a runtime value beside values of a known plain type or displays: all of
            # them are runtime values in the display
            return all(getattr(v, "_dynamic", False) or _is_display(v)
                       or kind(v) in ("int", "float", "str", "bool", "none") for v in values)
        if "?" in kinds:
            return False
        if kinds <= {"int", "float"} or kinds <= {"int", "bool"}:
            return False  # the backend has its own handling of mixed numbers
        return len(kinds) > 1

    display, deep = _is_display, _deep_box

    for node in ast.walk(tree):
        if isinstance(node, ast.List) and isinstance(node.ctx, ast.Load) and mixed(node.elts):
            node.elts = [deep(e) for e in node.elts]
        elif isinstance(node, ast.Dict) and all(k is not None for k in node.keys):
            if mixed(node.values):
                node.values = [deep(v) for v in node.values]
            elif (len({kind(v) for v in node.values}) > 1
                  and any(display(v) for v in node.values)):
                # Values of unknown type beside a nested display: the dict holds runtime
                # values, which V makes of a plain value by itself but not of a map or array.
                node.values = [deep(v) if display(v) else v for v in node.values]


_RUNTIME_API: Optional[Dict[str, Dict[str, Any]]] = None
# Modules whose calls are resolved here. The others in the manifest (json, pathlib, os,
# sys, time, re) still have their own lowering in the backend.
_RUNTIME_API_MODULES = ("datetime", "sqlite3", "pathlib", "logging", "argparse", "subprocess",
                        "hashlib", "uuid", "shutil", "tempfile", "base64", "secrets", "json", "re", "time",
                        "mcp")
# The classes of those modules that have a V type (runtime_class_types in the backend).
_RUNTIME_API_CLASS_SET: Optional[frozenset] = None


def _runtime_classes() -> frozenset:
    """The classes of the enabled runtime modules, by Python name: every manifest entry
    that states a V type, and every class named as the receiver of a method or property."""
    global _RUNTIME_API_CLASS_SET
    if _RUNTIME_API_CLASS_SET is None:
        found = set()
        for name, entry in _runtime_api().items():
            # (what `Path.stat()` gives is declared as the `os` module's class)
            if name.split(".")[0] not in _RUNTIME_API_MODULES and not name.startswith("os.stat_result"):
                continue
            if entry.get("v_type") and entry.get("kind") in ("class", "constructor"):
                found.add(name)
            receiver = entry.get("receiver")
            if receiver and entry.get("kind") in ("method", "property"):
                found.add(receiver)
        _RUNTIME_API_CLASS_SET = frozenset(found)
    return _RUNTIME_API_CLASS_SET


def _runtime_api() -> Dict[str, Dict[str, Any]]:
    """The runtime library's manifest (pyrt/api.json beside the frontend), by Python name."""
    global _RUNTIME_API
    if _RUNTIME_API is None:
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pyrt", "api.json")
        try:
            with open(path, "r", encoding="utf-8") as handle:
                _RUNTIME_API = {e["python"]: e for e in json.load(handle)}
        except (OSError, ValueError):
            _RUNTIME_API = {}
    return _RUNTIME_API


def _annotate_namespace_parameters(tree: ast.Module, table: symbols.SymbolTable) -> bool:
    """A parameter with no annotation that is only read as a parsed command line is
    annotated as one (`def cmd_list(args): ... args.limit`). The evidence: the file adds
    arguments to a parser, the parameter is never assigned, called on, indexed or
    iterated, at least one attribute of it is read, and every attribute read is the name
    of an argument the file adds (or `func`, `command`, the names subcommands set).
    Returns whether any parameter was annotated."""
    names: Set[str] = set()
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr in ("add_argument", "add_subparsers", "set_defaults")):
            continue
        if node.func.attr != "add_argument":
            names.update(k.arg for k in node.keywords if k.arg is not None)
            names.update(k.value.value for k in node.keywords
                         if k.arg == "dest" and isinstance(k.value, ast.Constant)
                         and isinstance(k.value.value, str))
            continue
        flags = [a.value for a in node.args
                 if isinstance(a, ast.Constant) and isinstance(a.value, str)]
        if not flags or len(flags) != len(node.args):
            continue
        dest = next((k.value.value for k in node.keywords if k.arg == "dest"
                     and isinstance(k.value, ast.Constant) and isinstance(k.value.value, str)), None)
        longs = [f for f in flags if f.startswith("--")]
        names.add(dest or (longs[0][2:] if longs else flags[0].lstrip("-")).replace("-", "_"))
    if not names:
        return False
    found = False
    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        params = {getattr(a, "_binding", None): a for a in fn.args.posonlyargs + fn.args.args
                  if a.arg not in ("self", "cls") and a.annotation is None}
        params.pop(None, None)
        if not params:
            continue
        read: Dict[int, Set[str]] = {b: set() for b in params}
        bases = set()
        for node in ast.walk(fn):
            if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) \
                    and isinstance(node.ctx, ast.Load):
                binding_id = getattr(node.value, "_binding", None)
                if binding_id in read:
                    read[binding_id].add(node.attr)
                    bases.add(id(node.value))
        other: Set[int] = set()
        for node in ast.walk(fn):
            if isinstance(node, ast.Name) and id(node) not in bases \
                    and getattr(node, "_binding", None) in read:
                other.add(node._binding)  # used whole, stored to, indexed or iterated
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
                    and id(node.func.value) in bases and node.func.attr not in ("func",):
                other.add(getattr(node.func.value, "_binding", None))  # a method called on it
        for binding_id, attrs in read.items():
            if (not attrs or binding_id in other or table.bindings[binding_id].rebound
                    or not attrs <= names):
                continue
            arg = params[binding_id]
            arg.annotation = ast.copy_location(ast.Name(id="Namespace", ctx=ast.Load()), arg)
            arg.annotation._api = "argparse.Namespace"
            found = True
    return found


def _annotate_database_parameters(tree: ast.Module, table: symbols.SymbolTable,
                                  api: Dict[str, Dict[str, Any]]) -> bool:
    """A parameter with no annotation (or annotated `Any` or `object`) that is only used as
    a database connection, or only as a cursor, is annotated as one. The evidence is the methods called on it: every one must be
    a method of the class, and at least one must belong to that class alone (`commit`,
    `cursor`, `rollback`, `executescript` for a connection; `fetchone`, `fetchall`,
    `fetchmany` for a cursor). A parameter on which only `execute` is called is a connection
    when the result of the call is fetched from or iterated, which a cursor's own `execute`
    result also allows, so there the parameter's name decides (`conn`, `db`; `cur`).
    Returns whether any parameter was annotated."""
    methods = {cls: {name.rsplit(".", 1)[1] for name, e in api.items()
                     if name.startswith(cls + ".") and e.get("kind") == "method"}
               for cls in ("sqlite3.Connection", "sqlite3.Cursor")}
    if not all(methods.values()):
        return False
    own = {"sqlite3.Connection": methods["sqlite3.Connection"] - methods["sqlite3.Cursor"],
           "sqlite3.Cursor": methods["sqlite3.Cursor"] - methods["sqlite3.Connection"]}
    found = False
    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        params = {getattr(a, "_binding", None): a
                  for a in fn.args.posonlyargs + fn.args.args + fn.args.kwonlyargs
                  if a.arg not in ("self", "cls") and (
                      a.annotation is None
                      # `Any` and `object` say nothing about the value either
                      or _unparse_expr(a.annotation) in ("Any", "object", "typing.Any"))}
        params.pop(None, None)
        if not params:
            continue
        called: Dict[int, Set[str]] = {b: set() for b in params}
        other: Set[int] = set()
        callees = set()
        for node in ast.walk(fn):
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                    and isinstance(node.func.value, ast.Name)):
                binding_id = getattr(node.func.value, "_binding", None)
                if binding_id in called:
                    called[binding_id].add(node.func.attr)
                    callees.add(id(node.func.value))
        for node in ast.walk(fn):
            if isinstance(node, ast.Name) and id(node) not in callees:
                binding_id = getattr(node, "_binding", None)
                if binding_id in called and isinstance(node.ctx, ast.Store):
                    other.add(binding_id)  # rebound: not one object
        for binding_id, names in called.items():
            if not names or binding_id in other or table.bindings[binding_id].rebound:
                continue
            fits = [cls for cls in methods if names <= methods[cls]]
            chosen = ""
            if len(fits) == 1:
                chosen = fits[0]
            elif len(fits) == 2:
                proven = [cls for cls in fits if names & own[cls]]
                word = params[binding_id].arg.lower()
                if len(proven) == 1:
                    chosen = proven[0]
                elif "conn" in word or word in ("db", "database"):
                    chosen = "sqlite3.Connection"
                elif word.startswith("cur"):
                    chosen = "sqlite3.Cursor"
            if chosen:
                arg = params[binding_id]
                arg.annotation = ast.Name(id=chosen.rsplit(".", 1)[1], ctx=ast.Load())
                ast.copy_location(arg.annotation, arg)
                arg.annotation._api = chosen
                found = True
    return found


def _annotate_subparser_parameters(tree: ast.Module, table: symbols.SymbolTable,
                                   api: "dict[str, dict[str, Any]]") -> bool:
    """Recognize an untyped parameter used only to add argparse subparsers."""
    cls = "argparse._SubParsersAction"
    if cls + ".add_parser" not in api:
        return False

    # Calling a method named add_parser does not establish an argparse receiver.
    # Only specialize helpers whose visible callers pass an actual subparser action.
    argparse_modules: Set[int] = set()
    parser_factories: Set[int] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                binding_id = getattr(alias, "_binding", None)
                if alias.name == "argparse" and binding_id is not None:
                    if not table.bindings[binding_id].rebound:
                        argparse_modules.add(binding_id)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module == "argparse":
            for alias in node.names:
                binding_id = getattr(alias, "_binding", None)
                if alias.name == "ArgumentParser" and binding_id is not None:
                    if not table.bindings[binding_id].rebound:
                        parser_factories.add(binding_id)

    def constructs_parser(value: ast.AST) -> bool:
        if not isinstance(value, ast.Call):
            return False
        func = value.func
        if isinstance(func, ast.Name):
            return getattr(func, "_binding", None) in parser_factories
        return (isinstance(func, ast.Attribute) and func.attr == "ArgumentParser"
                and isinstance(func.value, ast.Name)
                and getattr(func.value, "_binding", None) in argparse_modules)

    def constructs_action(value: ast.AST, parsers: Set[int]) -> bool:
        if not isinstance(value, ast.Call) or not isinstance(value.func, ast.Attribute):
            return False
        if value.func.attr != "add_subparsers":
            return False
        receiver = value.func.value
        return (isinstance(receiver, ast.Name)
                and getattr(receiver, "_binding", None) in parsers) or constructs_parser(receiver)

    assignments = [stmt for stmt in ast.walk(tree)
                   if isinstance(stmt, (ast.Assign, ast.AnnAssign))]
    parsers: Set[int] = set()
    for stmt in assignments:
        if not constructs_parser(stmt.value):
            continue
        targets = stmt.targets if isinstance(stmt, ast.Assign) else [stmt.target]
        for target in targets:
            if isinstance(target, ast.Name):
                binding_id = getattr(target, "_binding", None)
                if binding_id is not None and not table.bindings[binding_id].rebound:
                    parsers.add(binding_id)

    actions: Set[int] = set()
    for stmt in assignments:
        if not constructs_action(stmt.value, parsers):
            continue
        targets = stmt.targets if isinstance(stmt, ast.Assign) else [stmt.target]
        for target in targets:
            if isinstance(target, ast.Name):
                binding_id = getattr(target, "_binding", None)
                if binding_id is not None and not table.bindings[binding_id].rebound:
                    actions.add(binding_id)

    def receives_action(call: ast.Call, position: int, name: str) -> bool:
        supplied = (call.args[position] if position < len(call.args) else
                    next((kw.value for kw in call.keywords if kw.arg == name), None))
        if isinstance(supplied, ast.Name):
            return getattr(supplied, "_binding", None) in actions
        return constructs_action(supplied, parsers)

    calls: Dict[int, List[ast.Call]] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            binding_id = getattr(node.func, "_binding", None)
            if binding_id is not None:
                calls.setdefault(binding_id, []).append(node)

    found = False
    for fn in ast.walk(tree):
        if not isinstance(fn, ast.FunctionDef) or fn.decorator_list or _is_generator(fn):
            continue
        params = fn.args.posonlyargs + fn.args.args + fn.args.kwonlyargs
        if not any(arg.annotation is None for arg in params):
            continue
        callers = calls.get(getattr(fn, "_binding", None), [])
        nodes = list(ast.walk(fn))
        for position, arg in enumerate(params):
            binding_id = getattr(arg, "_binding", None)
            if (arg.annotation is not None or arg.arg in ("self", "cls")
                    or binding_id is None or table.bindings[binding_id].rebound):
                continue
            receivers = {id(node.func.value) for node in nodes
                         if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                         and node.func.attr == "add_parser"
                         and isinstance(node.func.value, ast.Name)
                         and getattr(node.func.value, "_binding", None) == binding_id}
            reads = [node for node in nodes if isinstance(node, ast.Name)
                     and getattr(node, "_binding", None) == binding_id]
            if not receivers or any(id(node) not in receivers for node in reads):
                continue
            if not callers or not all(receives_action(call, position, arg.arg)
                                      for call in callers):
                continue
            arg.annotation = ast.copy_location(ast.Name(id="_SubParsersAction", ctx=ast.Load()), arg)
            arg.annotation._api = cls
            found = True
    return found


def _unquote_annotations(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """An annotation written as text (`-> list["TextContent"]`, or any annotation of a file
    with names imported under `if TYPE_CHECKING:`) is read as the expression it spells, its
    names being the module's."""
    if table is None:
        return
    module_names = {b.name: b.id for b in table.bindings
                    if table.scopes[b.scope].kind == "module" and not b.rebound}

    class Unquote(ast.NodeTransformer):
        def visit_Constant(self, node: ast.Constant) -> ast.AST:
            if not isinstance(node.value, str):
                return node
            try:
                spelled = ast.parse(node.value.strip(), mode="eval").body
            except SyntaxError:
                return node
            for part in ast.walk(spelled):
                ast.copy_location(part, node)
                if isinstance(part, ast.Name) and part.id in module_names:
                    part._binding = module_names[part.id]
            return spelled

        def visit_Subscript(self, node: ast.Subscript) -> ast.AST:
            # the arguments of `Literal[...]` are values, not types
            if _unparse_expr(node.value).split(".")[-1] == "Literal":
                return node
            return self.generic_visit(node)

    def unquoted(annotation: Optional[ast.expr]) -> Optional[ast.expr]:
        if annotation is None or not any(
                isinstance(n, ast.Constant) and isinstance(n.value, str)
                for n in ast.walk(annotation)):
            return annotation
        return Unquote().visit(annotation)

    for node in ast.walk(tree):
        if isinstance(node, ast.arg):
            node.annotation = unquoted(node.annotation)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            node.returns = unquoted(node.returns)
        elif isinstance(node, ast.AnnAssign):
            node.annotation = unquoted(node.annotation)


def _drop_type_checking_blocks(tree: ast.Module) -> None:
    """`if TYPE_CHECKING:` at module level never runs: only its `else` is the program's.
    (After the passes that read the names it imports for annotations.)"""
    def checking(test: ast.expr) -> bool:
        return _unparse_expr(test) in ("TYPE_CHECKING", "typing.TYPE_CHECKING")

    kept: List[ast.stmt] = []
    for stmt in tree.body:
        if isinstance(stmt, ast.If) and checking(stmt.test):
            kept.extend(stmt.orelse)
        else:
            kept.append(stmt)
    tree.body[:] = kept


def _mark_runtime_api(tree: ast.Module, table: Optional[symbols.SymbolTable]) -> None:
    """Set `_api` on a call or attribute that reaches the runtime library through the
    file's imports: `datetime.now(...)` after `from datetime import datetime` is
    `datetime.datetime.now`, `timedelta(days=1)` is `datetime.timedelta`, and
    `timezone.utc` is `datetime.timezone.utc`. Only names bound once, by an import.
    (Type inference takes this over when it reads the manifest itself.)"""
    api = _runtime_api()
    if table is None or not api:
        return
    imported: Dict[int, str] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                binding_id = getattr(alias, "_binding", None)
                if binding_id is not None and alias.name.split(".")[0] in _RUNTIME_API_MODULES + ("os",):
                    # `import a.b` binds `a`; `import a.b as c` binds the whole path
                    imported[binding_id] = alias.name if alias.asname else alias.name.split(".")[0]
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            if node.module.split(".")[0] not in _RUNTIME_API_MODULES + ("os",):
                continue
            for alias in node.names:
                binding_id = getattr(alias, "_binding", None)
                if binding_id is not None and alias.name != "*":
                    imported[binding_id] = node.module + "." + alias.name
    imported = {b: q for b, q in imported.items() if not table.bindings[b].rebound}
    ducked = _annotate_database_parameters(tree, table, api)
    ducked = _annotate_namespace_parameters(tree, table) or ducked
    ducked = _annotate_subparser_parameters(tree, table, api) or ducked
    if not imported and not ducked:
        return

    def qualified(node: ast.AST) -> str:
        if isinstance(node, ast.Name):
            return imported.get(getattr(node, "_binding", None), "")
        if isinstance(node, ast.Attribute):
            base = qualified(node.value)
            return base + "." + node.attr if base else ""
        return ""

    # A runtime class named in an annotation
    def mark_annotation(annotation: Optional[ast.AST]) -> None:
        if annotation is None:
            return
        for part in ast.walk(annotation):
            if isinstance(part, (ast.Name, ast.Attribute)):
                name = qualified(part)
                if name in _runtime_classes():
                    part._api = name

    for node in ast.walk(tree):
        if isinstance(node, ast.arg):
            mark_annotation(node.annotation)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            mark_annotation(node.returns)
        elif isinstance(node, ast.AnnAssign):
            mark_annotation(node.annotation)

    def standard_stream(node: ast.AST) -> str:
        # `sys.stdout` or `sys.stderr`, where `sys` is the module
        if (isinstance(node, ast.Attribute) and node.attr in ("stdout", "stderr")
                and isinstance(node.value, ast.Name) and node.value.id == "sys"):
            binding_id = getattr(node.value, "_binding", None)
            if binding_id is None or table.bindings[binding_id].kind == "import":
                return node.attr
        return ""

    def environ(node: ast.AST) -> bool:
        return isinstance(node, ast.Attribute) and qualified(node) == "os.environ"

    def environ_call(name: str, args: List[ast.expr], like: ast.AST) -> ast.Call:
        call = ast.Call(func=ast.Name(id="environ", ctx=ast.Load()), args=args, keywords=[])
        for part in (call, call.func):
            ast.copy_location(part, like)
        call._api = name
        return call

    def key_of(node: ast.AST) -> Optional[ast.expr]:
        if (isinstance(node, ast.Subscript) and environ(node.value)
                and not isinstance(node.slice, (ast.Slice, ast.Tuple))):
            return node.slice
        return None

    class Environ(ast.NodeTransformer):
        """`os.environ` used as the mapping it is: each form is the runtime call that reads
        or changes the process environment. `os.environ.get` is marked with the calls."""

        def visit_Assign(self, node: ast.Assign) -> ast.AST:
            key = key_of(node.targets[0]) if len(node.targets) == 1 else None
            if key is None:
                return self.generic_visit(node)
            call = environ_call("os.putenv", [self.visit(key), self.visit(node.value)], node)
            return ast.copy_location(ast.Expr(value=call), node)

        def visit_Delete(self, node: ast.Delete) -> ast.AST:
            keys = [key_of(target) for target in node.targets]
            if any(key is None for key in keys):
                return self.generic_visit(node)
            return [ast.copy_location(ast.Expr(value=environ_call(
                "os.environ.__delitem__", [self.visit(key)], node)), node) for key in keys]

        def visit_Expr(self, node: ast.Expr) -> ast.AST:
            call = node.value
            if (isinstance(call, ast.Call) and isinstance(call.func, ast.Attribute)
                    and call.func.attr == "pop" and environ(call.func.value)
                    and not call.keywords and len(call.args) in (1, 2)
                    and not isinstance(call.args[0], ast.Starred)):
                # with a default nothing is raised for a name that is not set
                name = "os.unsetenv" if len(call.args) == 2 else "os.environ.__delitem__"
                node.value = environ_call(name, [self.visit(call.args[0])], call)
                return node
            return self.generic_visit(node)

        def visit_Subscript(self, node: ast.Subscript) -> ast.AST:
            key = key_of(node) if isinstance(node.ctx, ast.Load) else None
            if key is None:
                return self.generic_visit(node)
            return environ_call("os.environ.__getitem__", [self.visit(key)], node)

        def visit_Compare(self, node: ast.Compare) -> ast.AST:
            if (len(node.ops) == 1 and isinstance(node.ops[0], (ast.In, ast.NotIn))
                    and environ(node.comparators[0])):
                call = environ_call("os.environ.__contains__", [self.visit(node.left)], node)
                if isinstance(node.ops[0], ast.NotIn):
                    return ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=call), node)
                return call
            return self.generic_visit(node)

        def visit_Call(self, node: ast.Call) -> ast.AST:
            func = node.func
            if isinstance(func, ast.Attribute) and environ(func.value):
                node.args = [self.visit(a) for a in node.args]
                for kw in node.keywords:
                    kw.value = self.visit(kw.value)
                if func.attr == "copy" and not node.args and not node.keywords:
                    return environ_call("os.environ.copy", [], node)
                if func.attr == "setdefault" and len(node.args) == 2 and not node.keywords:
                    return environ_call("os.environ.setdefault", node.args, node)
                if func.attr in ("items", "keys", "values"):
                    func.value = environ_call("os.environ.copy", [], func.value)
                return node
            if (isinstance(func, ast.Name) and func.id == "dict"
                    and getattr(func, "_binding", None) is None and len(node.args) == 1
                    and not node.keywords and environ(node.args[0])):
                return environ_call("os.environ.copy", [], node)
            return self.generic_visit(node)

        def visit_Attribute(self, node: ast.Attribute) -> ast.AST:
            # the mapping itself as a value (`env=os.environ`, `{**os.environ}`): what it holds now
            if environ(node) and isinstance(node.ctx, ast.Load):
                return environ_call("os.environ.copy", [], node)
            return self.generic_visit(node)

    if any(q == "os" or q.startswith("os.environ") for q in imported.values()):
        Environ().visit(tree)

    callees = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            callees.add(id(node.func))
            name = qualified(node.func)
            if name.startswith("logging."):
                # the logging runtime names a standard stream by its name
                for kw in node.keywords:
                    if standard_stream(kw.value):
                        kw.value = ast.copy_location(ast.Constant(value=standard_stream(kw.value)), kw.value)
                node.args = [ast.copy_location(ast.Constant(value=standard_stream(a)), a)
                             if standard_stream(a) else a for a in node.args]
            if name in ("os.environ.get", "os.getenv") and not node.keywords and not any(
                    isinstance(a, ast.Starred) for a in node.args):
                # one name: the value or None; with a default: always text
                if len(node.args) == 2 and isinstance(node.args[1], ast.Constant) \
                        and node.args[1].value is None:
                    node.args = node.args[:1]
                if len(node.args) == 1:
                    node._api = "os.getenv"
                elif len(node.args) == 2:
                    node._api = "os.environ.get"
                continue
            if name.startswith("os.") and name != "os.getcwd":
                # The rest of `os` is still lowered by the backend.
                continue
            if api.get(name, {}).get("kind") in ("function", "constructor"):
                node._api = name
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute) and id(node) not in callees:
            name = qualified(node)
            if api.get(name, {}).get("kind") == "constant" and not name.startswith("os."):
                node._api = name

    # Methods and properties of runtime objects: the class of a value is known where it
    # comes from a marked call, an annotation, or a name every binding of which gives it
    # the same class.
    def class_of(type_text: str) -> str:
        parts = [p.strip() for p in type_text.split("|") if p.strip() != "None"]
        return parts[0] if len(parts) == 1 and "[" not in parts[0] else ""

    def element_of(type_text: str) -> str:
        text = type_text.strip()
        for head in ("list[", "Iterable[", "Iterator[", "Sequence["):
            if text.startswith(head) and text.endswith("]"):
                return text[len(head):-1]
        return ""

    binding_types: Dict[int, str] = {}
    def annotated(annotation: Optional[ast.AST]) -> str:
        """The runtime class an annotation names, or `list[C]` for a list of one."""
        if annotation is None:
            return ""
        direct = getattr(annotation, "_api", "")
        if direct:
            return direct
        if (isinstance(annotation, ast.Subscript) and isinstance(annotation.value, ast.Name)
                and annotation.value.id in ("list", "List", "Sequence", "Iterable")):
            inner = getattr(annotation.slice, "_api", "")
            return "list[" + inner + "]" if inner else ""
        return ""

    declared_returns = {getattr(fn, "_binding", None): annotated(fn.returns)
                        for fn in ast.walk(tree)
                        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef))
                        and annotated(fn.returns)}

    def type_of(node: ast.AST) -> str:
        if isinstance(node, ast.Call):
            marked = getattr(node, "_api", "")
            if marked:
                return api[marked].get("returns") or "" if marked in api else ""
            if isinstance(node.func, ast.Attribute):
                cls = class_of(type_of(node.func.value))
                entry = api.get(cls + "." + node.func.attr) if cls in _runtime_classes() else None
                if entry and entry["kind"] == "method":
                    node._api = cls + "." + node.func.attr
                    return entry.get("returns") or ""
            if isinstance(node.func, ast.Name):
                # A function of this file annotated as returning a runtime class
                return declared_returns.get(getattr(node.func, "_binding", None), "")
            return ""
        if isinstance(node, ast.Name):
            return binding_types.get(getattr(node, "_binding", None), "")
        if isinstance(node, ast.Subscript) and not isinstance(node.slice, ast.Slice):
            # one element of a list of runtime objects
            return element_of(type_of(node.value))
        if isinstance(node, ast.List) and node.elts:
            # a display whose elements are all of one runtime class
            classes = {class_of(type_of(e)) for e in node.elts}
            only = next(iter(classes)) if len(classes) == 1 else ""
            return "list[" + only + "]" if only in _runtime_classes() else ""
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div):
            # `path / "name"` is a path
            return "pathlib.Path" if class_of(type_of(node.left)) == "pathlib.Path" else ""
        if isinstance(node, ast.Attribute):
            cls = class_of(type_of(node.value))
            entry = api.get(cls + "." + node.attr) if cls in _runtime_classes() else None
            if entry and entry["kind"] == "property" and id(node) not in callees:
                node._api = cls + "." + node.attr
                return entry.get("returns") or ""
        return ""

    for _ in range(4):
        seen: Dict[int, Set[str]] = {}

        def bind(target: ast.AST, type_text: str) -> None:
            binding_id = getattr(target, "_binding", None) if isinstance(target, ast.Name) else None
            if binding_id is not None:
                seen.setdefault(binding_id, set()).add(type_text)

        for node in ast.walk(tree):
            if isinstance(node, ast.Assign) and len(node.targets) == 1:
                bind(node.targets[0], type_of(node.value))
            elif isinstance(node, ast.AnnAssign) and node.value is not None:
                bind(node.target, getattr(node.annotation, "_api", "") or type_of(node.value))
            elif isinstance(node, ast.arg):
                binding_id = getattr(node, "_binding", None)
                if binding_id is not None:
                    seen.setdefault(binding_id, set()).add(annotated(node.annotation))
            elif isinstance(node, (ast.With, ast.AsyncWith)):
                for item in node.items:
                    if item.optional_vars is not None:
                        bind(item.optional_vars, type_of(item.context_expr))
            elif isinstance(node, (ast.For, ast.AsyncFor, ast.comprehension)):
                bind(node.target, element_of(type_of(node.iter)))
        settled = {b: next(iter(ts)) for b, ts in seen.items()
                   if len(ts) == 1 and next(iter(ts)) and len(table.bindings[b].sites) <= 1
                   or (len(ts) == 1 and next(iter(ts)) and not table.bindings[b].is_param
                       and not table.bindings[b].declared_global)}
        if settled == binding_types:
            break
        binding_types = settled
    for node in ast.walk(tree):
        if isinstance(node, (ast.Call, ast.Attribute)):
            type_of(node)
    # for `_declare_block_locals`: the names that hold a runtime object, by binding
    tree._runtime_binding_types = dict(binding_types)

    def row_item(row: ast.expr, index: int, like: ast.AST) -> ast.Call:
        key = ast.Constant(value=index)
        call = ast.Call(func=ast.Attribute(value=row, attr="get", ctx=ast.Load()),
                        args=[key], keywords=[])
        for part in (key, call, call.func):
            ast.copy_location(part, like)
        call._api = "sqlite3.Row.__getitem__"
        call._dynamic = True
        return call

    def plain_names(target: ast.AST) -> List[ast.Name]:
        elts = target.elts if isinstance(target, (ast.Tuple, ast.List)) else []
        return list(elts) if elts and all(isinstance(e, ast.Name) for e in elts) else []

    row_counter = [0]

    class RowUnpack(ast.NodeTransformer):
        """`a, b = row` and `for a, b in rows` on database rows: each name is given its
        column, as a row is not a V tuple."""

        def visit_Assign(self, node: ast.Assign) -> Any:
            self.generic_visit(node)
            names = plain_names(node.targets[0]) if len(node.targets) == 1 else []
            if (not names or not isinstance(node.value, ast.Name)
                    or class_of(type_of(node.value)) != "sqlite3.Row"):
                return node
            made = []
            for index, name in enumerate(names):
                source = ast.copy_location(ast.Name(id=node.value.id, ctx=ast.Load()), node.value)
                source._binding = getattr(node.value, "_binding", None)
                if "None" in type_of(node.value):
                    source._api = "sqlite3.must_row"
                made.append(ast.copy_location(
                    ast.Assign(targets=[name], value=row_item(source, index, node)), node))
            return made

        def visit_For(self, node: ast.For) -> Any:
            self.generic_visit(node)
            names = plain_names(node.target)
            if not names or class_of(element_of(type_of(node.iter))) != "sqlite3.Row":
                return node
            row_counter[0] += 1
            row = f"py2v_row{row_counter[0]}"
            node.body[0:0] = [ast.copy_location(ast.Assign(
                targets=[name],
                value=row_item(ast.copy_location(ast.Name(id=row, ctx=ast.Load()), node), index, node)),
                node) for index, name in enumerate(names)]
            node.target = ast.copy_location(ast.Name(id=row, ctx=ast.Store()), node.target)
            return node

    RowUnpack().visit(tree)

    # A runtime object that may be None, used as a condition: it is true when it is there.
    def optional_row(node: ast.AST) -> bool:
        # a name or a call that gives a runtime object or None (a row, a regex match)
        if not isinstance(node, (ast.Name, ast.Call)):
            return False
        text = type_of(node)
        return "None" in text.split("|")[-1] and class_of(text) in _runtime_classes()

    def stated(test: ast.expr) -> ast.expr:
        if isinstance(test, ast.BoolOp):
            test.values = [stated(v) for v in test.values]
        elif isinstance(test, ast.UnaryOp) and isinstance(test.op, ast.Not):
            if optional_row(test.operand):
                nothing = ast.copy_location(ast.Constant(value=None), test)
                return ast.copy_location(ast.Compare(left=test.operand, ops=[ast.Is()],
                                                     comparators=[nothing]), test)
            test.operand = stated(test.operand)
        elif optional_row(test):
            nothing = ast.copy_location(ast.Constant(value=None), test)
            return ast.copy_location(ast.Compare(left=test, ops=[ast.IsNot()],
                                                 comparators=[nothing]), test)
        return test

    for node in ast.walk(tree):
        if isinstance(node, (ast.If, ast.While, ast.IfExp, ast.Assert)):
            node.test = stated(node.test)
        elif isinstance(node, ast.comprehension):
            node.ifs = [stated(test) for test in node.ifs]

    class Truth(ast.NodeTransformer):
        """`bool(x)` of such a value is whether it is there."""

        def visit_Call(self, node: ast.Call) -> ast.AST:
            self.generic_visit(node)
            if (isinstance(node.func, ast.Name) and node.func.id == "bool"
                    and getattr(node.func, "_binding", None) is None and len(node.args) == 1
                    and not node.keywords and optional_row(node.args[0])):
                nothing = ast.copy_location(ast.Constant(value=None), node)
                return ast.copy_location(ast.Compare(left=node.args[0], ops=[ast.IsNot()],
                                                     comparators=[nothing]), node)
            return node

    Truth().visit(tree)

    # `row[0]` and `row["name"]` on a database row are its `get` and `by_name`
    class RowIndex(ast.NodeTransformer):
        def visit_Subscript(self, node: ast.Subscript) -> ast.AST:
            self.generic_visit(node)
            if not isinstance(node.ctx, ast.Load) or class_of(type_of(node.value)) != "sqlite3.Row":
                return node
            key = node.slice
            if isinstance(key, ast.Constant) and isinstance(key.value, str):
                method = "by_name"
            elif isinstance(key, ast.Slice):
                return node
            else:
                method = "__getitem__"
            if isinstance(node.value, ast.Name) and "None" in type_of(node.value):
                # a name that may hold None: the backend unwraps it where it is indexed
                node.value._api = "sqlite3.must_row"
            call = ast.Call(func=ast.Attribute(value=node.value, attr="get", ctx=ast.Load()),
                            args=[key], keywords=[])
            ast.copy_location(call, node)
            ast.copy_location(call.func, node)
            call._api = "sqlite3.Row." + method
            call._dynamic = True
            return call

    RowIndex().visit(tree)

    # subprocess. `stdout` and `stderr` of a finished process are str when the call asked
    # for text, bytes otherwise, None when not captured. Where every `subprocess.run` of
    # the file asks for text they are read as text; elsewhere as runtime values.
    runs = [n for n in ast.walk(tree) if isinstance(n, ast.Call)
            and getattr(n, "_api", "") in ("subprocess.run", "subprocess.Popen", "subprocess.check_output")]

    def asks_for_text(call: ast.Call) -> bool:
        for kw in call.keywords:
            if kw.arg in ("text", "universal_newlines") and isinstance(kw.value, ast.Constant) and kw.value.value is True:
                return True
            if kw.arg == "encoding":
                return True
        return False

    all_text = bool(runs) and all(asks_for_text(c) for c in runs)

    class ProcessText(ast.NodeTransformer):
        def visit_Attribute(self, node: ast.Attribute) -> ast.AST:
            self.generic_visit(node)
            if getattr(node, "_api", "") not in ("subprocess.CompletedProcess.stdout",
                                                "subprocess.CompletedProcess.stderr"):
                return node
            if not all_text:
                node._dynamic = True
                return node
            call = ast.Call(func=ast.Attribute(value=node.value, attr=node.attr + "_text", ctx=ast.Load()),
                            args=[], keywords=[])
            ast.copy_location(call, node)
            ast.copy_location(call.func, node)
            call._api = node._api + "_text"
            call._api_returns = "str"
            return call

    if runs:
        ProcessText().visit(tree)

    # argparse. Each `add_argument` of the file says what an attribute of the parsed
    # namespace holds: its name (dest) and whether it is a str, an int, a float, a bool, a
    # list of str, or something that may be None (then it is read as a runtime value).
    dests: Dict[str, Set[str]] = {}

    def constant_text(node: Optional[ast.AST]) -> Optional[str]:
        return node.value if isinstance(node, ast.Constant) and isinstance(node.value, str) else None

    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and getattr(node, "_api", "").endswith(".add_argument")):
            continue
        names = [constant_text(a) for a in node.args]
        if not names or any(n is None for n in names):
            node._api = ""  # computed option names: left to the older lowering
            continue
        keywords = {k.arg: k.value for k in node.keywords if k.arg is not None}
        longs = [n for n in names if n.startswith("--")]
        dest = constant_text(keywords.get("dest")) or (
            longs[0][2:] if longs else names[0].lstrip("-")).replace("-", "_")
        positional = not names[0].startswith("-")
        action = constant_text(keywords.get("action")) or "store"
        nargs = keywords.get("nargs")
        declared = keywords.get("type")
        default = keywords.get("default")
        has_default = default is not None and not (
            isinstance(default, ast.Constant) and default.value is None)
        required = isinstance(keywords.get("required"), ast.Constant) and keywords["required"].value is True
        if action in ("store_true", "store_false"):
            kind = "bool"
        elif action == "count":
            kind = "int" if has_default else "value"
        elif action == "append" or (nargs is not None and constant_text(nargs) != "?"):
            always = has_default or (positional and constant_text(nargs) in ("+", None)) or required
            kind = "strings" if always and (declared is None or _unparse_expr(declared) == "str") else "value"
        elif not (has_default or required or (positional and nargs is None)):
            kind = "value"  # None when the option is absent
        elif declared is None or _unparse_expr(declared) == "str":
            kind = "str"
        elif _unparse_expr(declared) in ("int", "float"):
            kind = _unparse_expr(declared)
        else:
            kind = "value"
        dests.setdefault(dest, set()).add(kind)
        # the option strings as one list, and the values the runtime takes as runtime values
        packed = ast.List(elts=list(node.args), ctx=ast.Load())
        ast.copy_location(packed, node)
        node.args = [packed]
        for kw in node.keywords:
            if kw.arg in ("default", "const"):
                kw.value = _runtime_call("box", [kw.value], kw.value)
            elif kw.arg == "choices" and isinstance(kw.value, (ast.List, ast.Tuple)):
                kw.value = ast.copy_location(ast.List(
                    elts=[_runtime_call("box", [e], e) for e in kw.value.elts], ctx=ast.Load()), kw.value)

    accessors = {"str": "get_str", "int": "get_int", "float": "get_float", "bool": "get_bool",
                 "strings": "get_strings", "value": "require"}

    class NamespaceAttribute(ast.NodeTransformer):
        def visit_Attribute(self, node: ast.Attribute) -> ast.AST:
            is_namespace = (isinstance(node.ctx, ast.Load) and id(node) not in callees
                            and class_of(type_of(node.value)) == "argparse.Namespace")
            self.generic_visit(node)
            if not is_namespace:
                return node
            kinds = dests.get(node.attr, set())
            kind = next(iter(kinds)) if len(kinds) == 1 else "value"
            call = ast.Call(func=ast.Attribute(value=node.value, attr=accessors[kind], ctx=ast.Load()),
                            args=[ast.Constant(value=node.attr)], keywords=[])
            for part in ast.walk(call):
                if not hasattr(part, "lineno"):
                    ast.copy_location(part, node)
            call._api = "argparse.Namespace." + accessors[kind]
            if kind == "value":
                call._dynamic = True
                return call
            call._api_returns = {"strings": ""}.get(kind, kind)
            if kind != "int":
                return call
            # the runtime's integers are 64-bit values of their own type
            whole = ast.Call(func=ast.Name(id="int", ctx=ast.Load()), args=[call], keywords=[])
            ast.copy_location(whole, node)
            ast.copy_location(whole.func, node)
            return whole

    if dests:
        NamespaceAttribute().visit(tree)

    # `path / part` is `path.joinpath(part)`; a part that is itself a path joins as its text
    class PathJoin(ast.NodeTransformer):
        def visit_BinOp(self, node: ast.BinOp) -> ast.AST:
            is_join = isinstance(node.op, ast.Div) and type_of(node) == "pathlib.Path"
            right_is_path = is_join and class_of(type_of(node.right)) == "pathlib.Path"
            self.generic_visit(node)
            if not is_join:
                return node
            part = node.right
            if right_is_path:
                part = ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[part], keywords=[])
                ast.copy_location(part, node.right)
                ast.copy_location(part.func, node.right)
                part._api = "pathlib.Path.__str__"
            call = ast.Call(func=ast.Attribute(value=node.left, attr="joinpath", ctx=ast.Load()),
                            args=[part], keywords=[])
            ast.copy_location(call, node)
            ast.copy_location(call.func, node)
            call._api = "pathlib.Path.joinpath"
            return call

    PathJoin().visit(tree)
    for node in ast.walk(tree):
        marked = getattr(node, "_api", "")
        if marked in api and isinstance(node, (ast.Call, ast.Attribute)):
            node._api_returns = api[marked].get("returns") or ""
            if node._api_returns == "Any" and isinstance(node, ast.Call):
                # what the runtime gives back as a value of no stated type (`json.loads`)
                node._dynamic = True


def _mark_isinstance_inferred(tree: ast.Module, table: Optional[symbols.SymbolTable],
                              facts: Optional[infer.TypeFacts]) -> None:
    """Set `_subject_class` on `isinstance(name, ...)` when every value the code gives the
    name has one of the six plain types. `_mark_isinstance_subjects` covers annotated
    parameters; this covers the names whose type the code itself shows."""
    if table is None or facts is None:
        return
    plain = ("int", "float", "str", "bool", "list", "dict")
    if any(b.name in plain + ("isinstance",) for b in table.bindings):
        return
    inferred = {b["id"]: b.get("inferred") for b in facts.bindings}
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == "isinstance" and len(node.args) == 2
                and not node.keywords and isinstance(node.args[0], ast.Name)):
            continue
        if getattr(node, "_subject_class", ""):
            continue
        type_id = inferred.get(getattr(node.args[0], "_binding", None))
        if type_id is None:
            continue
        kind = facts.types[type_id]["k"]
        if kind in plain:
            node._subject_class = kind


def _annotation_node(text: str, like: ast.AST) -> ast.expr:
    annotation = ast.parse(text, mode="eval").body
    for part in ast.walk(annotation):
        ast.copy_location(part, like)
    return annotation


def _parameterize_bare_containers(tree: ast.Module, table: Optional[symbols.SymbolTable],
                                  facts: Optional[infer.TypeFacts]) -> None:
    """Give a parameter annotated with a bare `list` or `dict` the element types the code
    shows for it (`xs: list` called with `[1, 2]` becomes `xs: list[int]`)."""
    if table is None or facts is None:
        return
    known = {b["id"]: b.get("inferred") for b in facts.bindings}
    for node in ast.walk(tree):
        if not (isinstance(node, ast.arg) and isinstance(node.annotation, ast.Name)
                and node.annotation.id in ("list", "dict", "List", "Dict")):
            continue
        type_id = known.get(getattr(node, "_binding", None))
        if type_id is None:
            continue
        text = _annotation_for_type(facts.types, type_id)
        if text and text.lower().startswith(node.annotation.id.lower() + "["):
            node.annotation = _annotation_node(text, node.annotation)
    # The same for a return annotated with a bare `list` or `dict`.
    returns = {f["scope"]: f.get("ret_inferred") for f in facts.functions}
    for node in ast.walk(tree):
        if not (isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                and isinstance(node.returns, ast.Name)
                and node.returns.id in ("list", "dict", "List", "Dict")):
            continue
        type_id = returns.get(getattr(node, "_scope_id", None))
        if type_id is None:
            continue
        text = _annotation_for_type(facts.types, type_id)
        if text and text.lower().startswith(node.returns.id.lower() + "["):
            node.returns = _annotation_node(text, node.returns)


def _empty_field_annotations(tree: ast.Module, facts: infer.TypeFacts) -> Dict[int, str]:
    """For each `self.attr = []` or `self.attr = {}` in a method of a class without bases,
    the annotation that spells the field's type when inference knows all of it and the
    class does not declare the field itself. Keyed by id() of the assignment."""
    by_class = {c["binding"]: c for c in facts.classes}
    found: Dict[int, str] = {}
    first_set = set()

    def statements(node: ast.AST):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, ast.ClassDef):
                continue
            yield child
            yield from statements(child)

    for cls in ast.walk(tree):
        if not isinstance(cls, ast.ClassDef) or cls.bases or cls.keywords:
            continue
        fact = by_class.get(getattr(cls, "_binding", None))
        if fact is None:
            continue
        declared = fact.get("fields_declared", {})
        known = fact.get("fields_assumed", fact["fields"])
        for method in cls.body:
            if not isinstance(method, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            if method.decorator_list or not method.args.args:
                continue
            receiver = method.args.args[0].arg
            for stmt in statements(method):
                if not (isinstance(stmt, ast.Assign) and len(stmt.targets) == 1):
                    continue
                target = stmt.targets[0]
                if not (isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name)
                        and target.value.id == receiver):
                    continue
                if target.attr in declared or target.attr not in known:
                    continue
                # Any other value: only where the field is first set, in `__init__`.
                if not _is_empty_container(stmt.value):
                    if method.name != "__init__" or (id(cls), target.attr) in first_set:
                        continue
                    first_set.add((id(cls), target.attr))
                text = _annotation_for_type(facts.types, known[target.attr])
                if text is None and isinstance(stmt.value, ast.List) and not stmt.value.elts:
                    # Elements not of one known type: runtime values. The uses of the field
                    # are marked for `_lower_dynamic_values`.
                    text = "list[Any]"
                    for use in ast.walk(cls):
                        if (isinstance(use, ast.Attribute) and use.attr == target.attr
                                and isinstance(use.value, ast.Name) and use.value.id == receiver):
                            use._any_list = True
                if text is not None:
                    found[id(stmt)] = text
    return found


def _loop_comprehensions(tree: ast.Module, facts: Optional[infer.TypeFacts]) -> None:
    """A comprehension the backend's `.filter(...).map(...)` form cannot say becomes the
    loop a V programmer writes: one that unpacks its items (`for k, v in d.items()`) or has
    more than one `for`. In a function, before the statement that uses it:

        names = [k for k, v in ranks.items() if v == rank]

    is `names: list[str] = []` and a `for` with an `if` that appends. Done where inference
    knows the whole type of what is collected, where the comprehension is evaluated exactly
    once and before anything else of its statement that could matter, and where its loop
    names are not names of the function."""
    if facts is None:
        return
    counter = [0]

    def spelled(node: ast.AST) -> Optional[str]:
        type_id = getattr(node, "_assumed", None)
        if type_id is None:
            type_id = getattr(node, "_type", None)
        return _annotation_for_type(facts.types, type_id) if type_id is not None else None

    def wanted(node: ast.AST) -> bool:
        if not isinstance(node, (ast.ListComp, ast.GeneratorExp, ast.DictComp)):
            return False
        if any(g.is_async for g in node.generators):
            return False
        unpacks = any(isinstance(g.target, (ast.Tuple, ast.List)) for g in node.generators)
        if not unpacks and len(node.generators) == 1:
            return False
        for g in node.generators:
            names = [g.target] if isinstance(g.target, ast.Name) else list(getattr(g.target, "elts", []))
            if not names or not all(isinstance(n, ast.Name) for n in names):
                return False
        if any(isinstance(n, (ast.NamedExpr, ast.Await, ast.Yield, ast.YieldFrom, ast.Lambda))
               for n in ast.walk(node)):
            return False
        if isinstance(node, ast.DictComp):
            return spelled(node.key) in ("str", "int") and spelled(node.value) is not None
        return spelled(node.elt) is not None

    def simple(node: ast.AST) -> bool:
        while isinstance(node, ast.Attribute):
            node = node.value
        return isinstance(node, (ast.Name, ast.Constant))

    def first_match(node: ast.AST) -> bool:
        """`next((x for x in xs if test), default)`: the first match, or the default."""
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == "next" and getattr(node.func, "_binding", None) is None
                and len(node.args) == 2 and not node.keywords
                and isinstance(node.args[0], ast.GeneratorExp)):
            return False
        gen, default = node.args
        if len(gen.generators) != 1 or gen.generators[0].is_async or not simple(default):
            return False
        target = gen.generators[0].target
        names = [target] if isinstance(target, ast.Name) else list(getattr(target, "elts", []))
        if not names or not all(isinstance(n, ast.Name) for n in names):
            return False
        if any(isinstance(n, (ast.NamedExpr, ast.Await, ast.Yield, ast.YieldFrom, ast.Lambda))
               for n in ast.walk(gen)):
            return False
        text = spelled(gen.elt)
        nothing = isinstance(default, ast.Constant) and default.value is None
        return text is not None and (nothing or spelled(default) == text)

    def generators(node: ast.AST) -> List[ast.comprehension]:
        return node.args[0].generators if isinstance(node, ast.Call) else node.generators

    def find(node: ast.AST, found: List[ast.AST]) -> bool:
        """Collect the comprehensions of an expression that are safe to run first, in the
        order Python reaches them. False once something else would have run before."""
        if wanted(node) or first_match(node):
            found.append(node)
            return True
        if simple(node):
            return True
        parts: List[ast.AST] = []
        if isinstance(node, ast.Call) and not any(k.arg is None for k in node.keywords):
            func = node.func
            if isinstance(func, ast.Attribute):
                parts.append(func.value)
            elif not isinstance(func, ast.Name):
                return False
            parts += node.args + [k.value for k in node.keywords]
        elif isinstance(node, ast.UnaryOp):
            parts = [node.operand]
        elif isinstance(node, ast.BinOp):
            parts = [node.left, node.right]
        elif isinstance(node, ast.Compare):
            parts = [node.left] + node.comparators
        elif isinstance(node, ast.Subscript) and not isinstance(node.slice, ast.Slice):
            parts = [node.value, node.slice]
        elif isinstance(node, ast.Starred):
            parts = [node.value]
        elif isinstance(node, (ast.Tuple, ast.List, ast.Set)):
            parts = list(node.elts)
        elif isinstance(node, ast.BoolOp):
            find(node.values[0], found)
            return False
        elif isinstance(node, ast.IfExp):
            find(node.test, found)
            return False
        else:
            return False
        for part in parts:
            if not find(part, found):
                return False
        # the call, operation or display itself runs after its parts: nothing later in
        # the statement may be moved in front of it
        return False if isinstance(node, (ast.Call, ast.Subscript, ast.BinOp, ast.Compare)) \
            and not found else not isinstance(node, ast.Call)

    def loop(comp: ast.AST, name: str, target: Optional[ast.Name] = None) -> List[ast.stmt]:
        def load() -> ast.Name:
            return ast.Name(id=name, ctx=ast.Load())

        if isinstance(comp, ast.Call):
            gen, default = comp.args
            text = spelled(gen.elt)
            if isinstance(default, ast.Constant) and default.value is None:
                text = f"Optional[{text}]"
            only = gen.generators[0]
            found_it: List[ast.stmt] = [ast.Assign(targets=[ast.Name(id=name, ctx=ast.Store())],
                                                   value=gen.elt), ast.Break()]
            if only.ifs:
                test = only.ifs[0] if len(only.ifs) == 1 else ast.BoolOp(op=ast.And(),
                                                                         values=list(only.ifs))
                found_it = [ast.If(test=test, body=found_it, orelse=[])]
            search = ast.For(target=only.target, iter=only.iter, body=found_it, orelse=[])
            declaration = ast.AnnAssign(target=target or ast.Name(id=name, ctx=ast.Store()),
                                        annotation=_annotation_node(text, comp), value=default,
                                        simple=1)
            made = [declaration, search]
            for stmt in made:
                for part in ast.walk(stmt):
                    if not hasattr(part, "lineno"):
                        ast.copy_location(part, comp)
            return made
        if isinstance(comp, ast.DictComp):
            text = f"dict[{spelled(comp.key)}, {spelled(comp.value)}]"
            empty: ast.expr = ast.Dict(keys=[], values=[])
            store = ast.Assign(targets=[ast.Subscript(value=load(), slice=comp.key,
                                                      ctx=ast.Store())], value=comp.value)
        else:
            text = f"list[{spelled(comp.elt)}]"
            empty = ast.List(elts=[], ctx=ast.Load())
            store = ast.Expr(value=ast.Call(func=ast.Attribute(value=load(), attr="append",
                                                               ctx=ast.Load()),
                                            args=[comp.elt], keywords=[]))
        body: List[ast.stmt] = [store]
        for g in reversed(comp.generators):
            if g.ifs:
                test = g.ifs[0] if len(g.ifs) == 1 else ast.BoolOp(op=ast.And(), values=list(g.ifs))
                body = [ast.If(test=test, body=body, orelse=[])]
            body = [ast.For(target=g.target, iter=g.iter, body=body, orelse=[])]
        declaration = ast.AnnAssign(target=target or ast.Name(id=name, ctx=ast.Store()),
                                    annotation=_annotation_node(text, comp), value=empty, simple=1)
        made = [declaration] + body
        for stmt in made:
            for part in ast.walk(stmt):
                if not hasattr(part, "lineno"):
                    ast.copy_location(part, comp)
        return made

    def headers(stmt: ast.stmt) -> List[ast.expr]:
        if isinstance(stmt, (ast.Assign, ast.AugAssign, ast.Expr, ast.Return)):
            return [stmt.value] if stmt.value is not None else []
        if isinstance(stmt, ast.AnnAssign):
            return [stmt.value] if stmt.value is not None else []
        if isinstance(stmt, ast.If):
            return [stmt.test]
        if isinstance(stmt, ast.For):
            return [stmt.iter]
        return []

    class Replace(ast.NodeTransformer):
        def __init__(self, names: Dict[int, str]) -> None:
            self.names = names

        def visit(self, node: ast.AST) -> ast.AST:
            if id(node) in self.names:
                name = ast.copy_location(ast.Name(id=self.names[id(node)], ctx=ast.Load()), node)
                for mark in ("_type", "_assumed"):
                    if hasattr(node, mark):
                        setattr(name, mark, getattr(node, mark))
                return name
            return self.generic_visit(node)

    def rewrite(stmts: List[ast.stmt], taken: Dict[str, int]) -> None:
        index = 0
        while index < len(stmts):
            stmt = stmts[index]
            for field in ("body", "orelse", "finalbody"):
                inner = getattr(stmt, field, None)
                if isinstance(inner, list) and inner and isinstance(inner[0], ast.stmt) \
                        and not isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    rewrite(inner, taken)
            for handler in getattr(stmt, "handlers", []):
                rewrite(handler.body, taken)
            for case in getattr(stmt, "cases", []):
                rewrite(case.body, taken)
            found: List[ast.AST] = []
            for expr in headers(stmt):
                find(expr, found)
            found = [c for c in found if not any(
                isinstance(n, ast.Name) and n.id in taken
                for g in generators(c) for n in ast.walk(g.target))]
            if not found:
                index += 1
                continue
            if (isinstance(stmt, ast.Assign) and len(stmt.targets) == 1
                    and isinstance(stmt.targets[0], ast.Name) and found == [stmt.value]
                    and taken.get(stmt.targets[0].id) == 1
                    and not any(isinstance(n, ast.Name) and n.id == stmt.targets[0].id
                                for n in ast.walk(stmt.value))):
                # the name is given the comprehension and nothing else: the loop fills it
                made = loop(stmt.value, stmt.targets[0].id, stmt.targets[0])
                stmts[index:index + 1] = made
                index += len(made)
                continue
            names: Dict[int, str] = {}
            before: List[ast.stmt] = []
            for comp in found:
                counter[0] += 1
                names[id(comp)] = f"py2v_{'first' if isinstance(comp, ast.Call) else 'comp'}{counter[0]}"
                before += loop(comp, names[id(comp)])
            for field, value in ast.iter_fields(stmt):
                if isinstance(value, ast.expr):
                    setattr(stmt, field, Replace(names).visit(value))
            stmts[index:index] = before
            index += len(before) + 1

    for fn in ast.walk(tree):
        if not isinstance(fn, ast.FunctionDef):
            continue
        # every name the function itself binds: a loop name equal to one would change it
        taken = {a.arg: 1 for a in ast.walk(fn.args) if isinstance(a, ast.arg)}
        pending = list(fn.body)
        while pending:
            node = pending.pop()
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda,
                                 ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    taken[node.name] = taken.get(node.name, 0) + 2
                continue
            if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
                taken[node.id] = taken.get(node.id, 0) + 1
            elif isinstance(node, (ast.Global, ast.Nonlocal)):
                for name in node.names:
                    taken[name] = taken.get(name, 0) + 2
            pending.extend(ast.iter_child_nodes(node))
        rewrite(fn.body, taken)


@dataclass
class _AssignmentFlow:
    """Assignments on normal, break, and continue exits of a statement block."""
    normal: Optional[Set[int]]
    breaks: List[Set[int]] = field(default_factory=list)
    continues: List[Set[int]] = field(default_factory=list)


def _definitely_assigned_loads(fn: Union[ast.FunctionDef, ast.AsyncFunctionDef]) -> Set[int]:
    """Return identities of eager loads assigned on every incoming normal path.

    This is deliberately conservative: calls may raise before any assignment in a
    try body, a with statement may suppress an exception, and deferred scopes do
    not run when they are defined. Expression-side assignments are not credited.
    """
    safe: Set[int] = set()
    unsafe: Set[int] = set()

    def expression(node: ast.AST, assigned: Set[int]) -> None:
        if isinstance(node, (ast.Lambda, ast.GeneratorExp)):
            return
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load):
            (safe if getattr(node, "_binding", None) in assigned else unsafe).add(id(node))
        for child in ast.iter_child_nodes(node):
            expression(child, assigned)

    def targets(node: ast.AST) -> Set[int]:
        return {part._binding for part in ast.walk(node)
                if isinstance(part, ast.Name) and isinstance(part.ctx, ast.Store)
                and hasattr(part, "_binding")}

    def joined(paths: List[Set[int]]) -> Optional[Set[int]]:
        return set.intersection(*paths) if paths else None

    def block(stmts: List[ast.stmt], initial: Set[int]) -> _AssignmentFlow:
        result = _AssignmentFlow(set(initial))
        for stmt in stmts:
            if result.normal is None:
                break
            step = statement(stmt, result.normal)
            result.normal = step.normal
            result.breaks.extend(step.breaks)
            result.continues.extend(step.continues)
        return result

    def statement(stmt: ast.stmt, assigned: Set[int]) -> _AssignmentFlow:
        current = set(assigned)
        if isinstance(stmt, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
            if stmt.value is not None:
                expression(stmt.value, current)
            lhs = stmt.targets if isinstance(stmt, ast.Assign) else [stmt.target]
            for target in lhs:
                expression(target, current)
                if isinstance(stmt, ast.AugAssign) and isinstance(target, ast.Name):
                    (safe if getattr(target, "_binding", None) in current else unsafe).add(id(target))
                if not isinstance(stmt, ast.AnnAssign) or stmt.value is not None:
                    current.update(targets(target))
            return _AssignmentFlow(current)
        if isinstance(stmt, ast.If):
            expression(stmt.test, current)
            yes, no = block(stmt.body, current), block(stmt.orelse, current)
            return _AssignmentFlow(joined([p for p in (yes.normal, no.normal) if p is not None]),
                                   yes.breaks + no.breaks, yes.continues + no.continues)
        if isinstance(stmt, (ast.For, ast.While)):
            certain = False
            body_entry = set(current)
            if isinstance(stmt, ast.For):
                expression(stmt.iter, current)
                expression(stmt.target, current)
                body_entry.update(targets(stmt.target))
                certain = (isinstance(stmt.iter, (ast.List, ast.Tuple)) and bool(stmt.iter.elts)
                           and not any(isinstance(item, ast.Starred) for item in stmt.iter.elts))
            else:
                expression(stmt.test, current)
                certain = isinstance(stmt.test, ast.Constant) and stmt.test.value is True
            body = block(stmt.body, body_entry)
            exhausted = [p for p in [body.normal] + body.continues if p is not None]
            if not certain:
                exhausted.append(current)
            if isinstance(stmt, ast.While) and certain:
                exhausted = []
            end = block(stmt.orelse, joined(exhausted)) if exhausted else _AssignmentFlow(None)
            paths = body.breaks + ([end.normal] if end.normal is not None else [])
            return _AssignmentFlow(joined(paths), end.breaks, end.continues)
        if isinstance(stmt, ast.Try):
            body = block(stmt.body, current)
            normal = block(stmt.orelse, body.normal) if body.normal is not None else _AssignmentFlow(None)
            paths = [normal.normal] if normal.normal is not None else []
            breaks, continues = body.breaks + normal.breaks, body.continues + normal.continues
            for handler in stmt.handlers:
                entry = set(current)
                if handler.type is not None:
                    expression(handler.type, current)
                outcome = block(handler.body, entry)
                paths.extend([outcome.normal] if outcome.normal is not None else [])
                breaks.extend(outcome.breaks)
                continues.extend(outcome.continues)
            if stmt.finalbody:
                # Finally also executes on exceptions and returns before the first write.
                final = block(stmt.finalbody, current)
                if final.normal is None:
                    return final
                paths = [p | final.normal for p in paths]
                breaks.extend(final.breaks)
                continues.extend(final.continues)
            return _AssignmentFlow(joined(paths), breaks, continues)
        if isinstance(stmt, (ast.With, ast.AsyncWith)):
            entry = set(current)
            for item in stmt.items:
                expression(item.context_expr, entry)
                if item.optional_vars is not None:
                    entry.update(targets(item.optional_vars))
            outcome = block(stmt.body, entry)
            return _AssignmentFlow(current, outcome.breaks, outcome.continues)
        if isinstance(stmt, (ast.Return, ast.Raise)):
            expression(stmt, current)
            return _AssignmentFlow(None)
        if isinstance(stmt, ast.Break):
            return _AssignmentFlow(None, [current])
        if isinstance(stmt, ast.Continue):
            return _AssignmentFlow(None, [], [current])
        if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            return _AssignmentFlow(current)
        expression(stmt, current)
        return _AssignmentFlow(current)

    params = {arg._binding for arg in ast.walk(fn.args) if isinstance(arg, ast.arg)
              and hasattr(arg, "_binding")}
    block(fn.body, params)
    # A later loop iteration or delayed exception-name cleanup can invalidate an
    # earlier write. Do not extend lifting for a binding that can be deleted.
    deleted = {getattr(node, "_binding", None) for node in ast.walk(fn)
               if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Del)}
    handler_names = {node.name for node in ast.walk(fn) if isinstance(node, ast.ExceptHandler)}
    invalid = {id(node) for node in ast.walk(fn) if isinstance(node, ast.Name)
               and (getattr(node, "_binding", None) in deleted or node.id in handler_names)}
    return safe - unsafe - invalid


def _declare_block_locals(tree: ast.Module, table: Optional[symbols.SymbolTable],
                          facts: Optional[infer.TypeFacts],
                          dynamic_bindings: Optional[set] = None) -> None:
    """Declare at the top of its function a local that Python first assigns inside a block
    and uses outside it.

    A Python local belongs to the whole function; a V variable belongs to the block that
    declares it. `if c: label = "a"` / `else: label = "b"` / `return label` needs `label`
    declared before the `if`. Where inference knows the local's whole type (int, float,
    str, bool, or a list or dict of those), the function gets `label: str` as a first
    statement, which the backend emits as a declaration with the type's zero value; the
    assignments then assign. A local whose type is not fully known is left as it was.

    With `dynamic_bindings` (the second run, from `_lower_dynamic_values`), the locals among
    them are declared instead, as `name: Any = None`: a value of unknown type."""
    if table is None or facts is None:
        return
    known = {b["id"]: b for b in facts.bindings}
    compound = (ast.If, ast.For, ast.AsyncFor, ast.While, ast.With, ast.AsyncWith, ast.Try)
    for fn in ast.walk(tree):
        if not isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        # each name occurrence of the function's own code, with the blocks around it
        occurrences: Dict[int, List[Tuple[Tuple[int, ...], ast.Name, Optional[ast.stmt]]]] = {}
        eager_occurrences: Dict[int, List[Tuple[Tuple[int, ...], ast.Name, Optional[ast.stmt]]]] = {}

        def walk(node: ast.AST, blocks: Tuple[int, ...], stmt: Optional[ast.stmt],
                 eager: Dict[int, List[Tuple[Tuple[int, ...], ast.Name, Optional[ast.stmt]]]] = eager_occurrences) -> None:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef,
                                 ast.GeneratorExp)):
                return
            if isinstance(node, (ast.ListComp, ast.SetComp, ast.DictComp)):
                for part in ast.walk(node):
                    if isinstance(part, ast.Name) and isinstance(part.ctx, ast.Load):
                        binding_id = getattr(part, "_binding", None)
                        if binding_id is not None:
                            eager.setdefault(binding_id, []).append((blocks, part, stmt))
                return
            if isinstance(node, ast.Name):
                binding_id = getattr(node, "_binding", None)
                if binding_id is not None:
                    occurrences.setdefault(binding_id, []).append((blocks, node, stmt))
                return
            if isinstance(node, compound) or type(node).__name__ in ("Match", "TryStar"):
                for field, value in ast.iter_fields(node):
                    if isinstance(value, list) and value and isinstance(value[0], (ast.stmt, ast.ExceptHandler)) \
                            or type(value).__name__ == "list" and field in ("cases",):
                        for index, child in enumerate(value):
                            inner = blocks + (hash((id(node), field, index if not isinstance(child, ast.stmt) else -1)),)
                            walk(child, inner, child if isinstance(child, ast.stmt) else stmt)
                    elif isinstance(value, ast.AST):
                        walk(value, blocks, stmt)
                    elif isinstance(value, list):
                        for child in value:
                            if isinstance(child, ast.AST):
                                walk(child, blocks, stmt)
                return
            if isinstance(node, ast.ExceptHandler) or type(node).__name__ == "match_case":
                for child in ast.iter_child_nodes(node):
                    walk(child, blocks, child if isinstance(child, ast.stmt) else stmt)
                return
            for child in ast.iter_child_nodes(node):
                walk(child, blocks, child if isinstance(child, ast.stmt) else stmt)

        for stmt in fn.body:
            walk(stmt, (), stmt)
        proven_loads = _definitely_assigned_loads(fn) if eager_occurrences else set()
        declarations: List[ast.stmt] = []
        for binding_id, found in occurrences.items():
            binding = table.bindings[binding_id]
            fact = known.get(binding_id)
            if (fact is None or fact.get("declared") is not None or binding.is_param
                    or binding.declared_global or binding.declared_nonlocal
                    or table.scopes[binding.scope].kind != "function"
                    or getattr(table.scopes[binding.scope], "_node", None) is not fn):
                continue
            found.sort(key=lambda o: (o[1].lineno, o[1].col_offset))
            blocks, first, stmt = found[0]
            if not blocks or not isinstance(first.ctx, ast.Store):
                continue
            if not (isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and stmt.targets[0] is first):
                continue  # a loop variable, a `with` name, an unpacking: declared by their own form
            if all(other[:len(blocks)] == blocks for other, _, _ in found):
                eager = eager_occurrences.get(binding_id, [])
                if not any(other[:len(blocks)] != blocks for other, _, _ in eager):
                    continue
                loads = [node for _, node, site in found + eager
                         if isinstance(node.ctx, ast.Load)
                         or isinstance(site, ast.AugAssign) and site.target is node]
                if not loads or any(id(node) not in proven_loads for node in loads):
                    continue  # preserve today's output when assignment is not proven
            type_id = fact.get("assumed", fact.get("inferred"))
            text = _annotation_for_type(facts.types, type_id) if type_id is not None else None
            value: Optional[ast.expr] = None
            runtime_class = ""
            if text is None and dynamic_bindings is None:
                # a runtime object, a list of one, or one that may be None
                held = getattr(tree, "_runtime_binding_types", {}).get(binding_id, "")
                parts = [p.strip() for p in held.split("|")]
                inner = parts[0][5:-1] if parts[0].startswith("list[") else parts[0]
                if inner in _runtime_classes() and len(parts) <= 2 and parts[1:] in ([], ["None"]) \
                        and not (parts[0].startswith("list[") and len(parts) == 2):
                    runtime_class = inner
                    text = "list[py2v_class]" if parts[0].startswith("list[") else (
                        "Optional[py2v_class]" if len(parts) == 2 else "py2v_class")
                    if len(parts) == 2:
                        value = ast.copy_location(ast.Constant(value=None), fn)
            if dynamic_bindings is not None:
                if text is not None or binding_id not in dynamic_bindings:
                    continue  # declared by the first run, or not a value of unknown type
                text = "Any"
                value = _runtime_call("box", [ast.copy_location(ast.Constant(value=None), fn)], fn)
            if text is None:
                continue
            target = ast.Name(id=first.id, ctx=ast.Store())
            target._binding = binding_id
            declaration = ast.AnnAssign(target=target, annotation=_annotation_node(text, fn),
                                        value=value, simple=1)
            for part in ast.walk(declaration.annotation):
                if isinstance(part, ast.Name) and part.id == "py2v_class":
                    part.id = runtime_class.rsplit(".", 1)[-1]
                    part._api = runtime_class
            ast.copy_location(target, fn)
            ast.copy_location(declaration, fn)
            declarations.append(declaration)
        if declarations:
            at = 1 if (fn.body and isinstance(fn.body[0], ast.Expr)
                       and isinstance(fn.body[0].value, ast.Constant)
                       and isinstance(fn.body[0].value.value, str)) else 0
            fn.body[at:at] = declarations


def _declare_inferred_containers(tree: ast.Module, table: Optional[symbols.SymbolTable],
                                 facts: Optional[infer.TypeFacts]) -> set:
    """Give `x = []` and `x = {}` the element types that the writes to `x` show.

    The first assignment of a name to an empty list or dict becomes the annotated
    assignment `x: list[T] = []` when inference knows the whole type, so the backend
    declares it as it does an annotated one. Nothing else about the name changes.
    A list whose elements are not of one known type is declared `list[Any]`, a list of
    runtime values; the bindings declared so are returned."""
    if facts is None:
        return set()
    inferred = {b["id"]: b for b in facts.bindings}
    field_text = _empty_field_annotations(tree, facts)
    any_lists: set = set()

    def annotated(stmt: ast.stmt) -> ast.stmt:
        if id(stmt) in field_text:
            annotation = _annotation_node(field_text[id(stmt)], stmt)
            new = ast.AnnAssign(target=stmt.targets[0], annotation=annotation,
                                value=stmt.value, simple=0)
            return ast.copy_location(new, stmt)
        if not (isinstance(stmt, ast.Assign) and len(stmt.targets) == 1
                and isinstance(stmt.targets[0], ast.Name)
                and _is_empty_container(stmt.value)):
            return stmt
        target = stmt.targets[0]
        binding_id = getattr(target, "_binding", None)
        fact = inferred.get(binding_id)
        if fact is None or fact.get("declared") is not None:
            return stmt
        known = fact.get("assumed", fact.get("inferred"))
        binding = table.bindings[binding_id]
        first = binding.sites[0]
        if (first[0], first[1]) != (target.lineno, target.col_offset):
            return stmt
        if binding.declared_global or binding.declared_nonlocal:
            return stmt
        text = _annotation_for_type(facts.types, known) if known is not None else None
        if text is None:
            # The elements are not of one known type: runtime values.
            if isinstance(stmt.value, ast.Dict) or (
                    isinstance(stmt.value, ast.Call) and stmt.value.func.id == "dict"):
                return stmt  # the backend declares an empty dict itself
            text = "list[Any]"
            any_lists.add(binding_id)
        annotation = ast.parse(text, mode="eval").body
        new = ast.AnnAssign(target=target, annotation=annotation, value=stmt.value, simple=1)
        ast.copy_location(new, stmt)
        for part in ast.walk(annotation):
            ast.copy_location(part, stmt)
        return new

    for node in ast.walk(tree):
        for field_name in ("body", "orelse", "finalbody"):
            block = getattr(node, field_name, None)
            if isinstance(block, list):
                block[:] = [annotated(s) if isinstance(s, ast.stmt) else s for s in block]
    return any_lists


def process_file(file_path: str, project: Optional[ProjectFacts] = None) -> str:
    """Parse, analyze, and return enriched JSON AST."""
    with open(file_path, "r", encoding="utf-8") as f:
        source = f.read()

    tree = ast.parse(source, filename=file_path)

    # Mark the walrus `if` tests the transpiler may hoist, before the
    # `__main__` guard becomes a function, so its block counts as module level
    _detect_walrus_hoists(tree)
    # V generic parameters are one capital letter
    _shorten_generic_names(tree)

    # isinstance() on a parameter whose annotation settles the answer
    _mark_isinstance_subjects(tree)

    # Rewrite __main__ guard
    tree = _rewrite_main_guard(tree)
    _plan_condition_walruses(tree)

    _drop_doctest_runs(tree)
    _lower_dataclass_fields(tree)
    _state_module_name(tree, project.module_name if project is not None else None)

    # Lexical bindings on the final scope structure, then the types the code shows
    table = _resolve_bindings(tree)
    _mark_math_members(tree, table)
    _unquote_annotations(tree, table)
    _mark_runtime_api(tree, table)
    _lower_exit_statements(tree, table)
    _erase_typing_casts(tree, table)
    _expand_bool_calls(tree)
    facts = _infer_types(tree, table, project)
    _loop_comprehensions(tree, facts)
    any_lists = _declare_inferred_containers(tree, table, facts)
    _declare_block_locals(tree, table, facts)
    _lower_optional_text_calls(tree, table, facts)
    _choose_boolop_values(tree, facts)
    _state_truth_tests(tree, table, facts)
    _mark_isinstance_inferred(tree, table, facts)
    _iterate_string_characters(tree, facts)
    if project is None:
        _annotate_parameters_from_calls(tree, table, facts)
    _annotate_returns(tree, facts)
    _lower_frozensets(tree, table)
    _lower_dynamic_values(tree, table, facts, any_lists)
    _box_mixed_displays(tree, table, facts)
    _parameterize_bare_containers(tree, table, facts)
    _mark_module_constants(tree, table)
    _plan_error_propagation(tree, table)
    _drop_type_checking_blocks(tree)

    # Detect class methods
    _detect_class_methods(tree)

    # Detect nesting levels
    _detect_nesting_levels(tree)

    # Track mutability
    ScopeTracker.mutating_methods = _mutating_method_names(tree)
    ScopeTracker.mutating_functions = _mutating_function_params(tree, table)
    tracker = ScopeTracker()
    tracker.visit(tree)
    mutable_vars = tracker.mutable

    # Find redefined targets
    redefined = _find_redefined_targets(tree)

    # Gather module-level variable annotations and function return annotations
    # into a per-file context so there is no cross-file state pollution.
    ctx = AnalysisContext(
        var_annotations=_gather_var_annotations(tree),
        func_ret_annotations=_gather_func_return_annotations(tree),
        slots_by_class=_collect_slots_by_class(tree),
        table=table,
        facts=facts,
    )
    ctx.class_field_types = _class_field_types(tree, ctx.slots_by_class)

    result = _node_to_dict(tree, mutable_vars, redefined, ctx)
    return json.dumps(result)


def _pattern_to_dict(pattern, mutable_vars, redefined, ctx):
    """Serialize a Python match pattern node to a dict for JSON output."""
    if pattern is None:
        return None
    t = type(pattern).__name__
    result = {"node_type": t}
    if t == "MatchValue":
        result["value"] = _node_to_dict(pattern.value, mutable_vars, redefined, ctx)
    elif t == "MatchSingleton":
        result["value"] = pattern.value  # None, True, or False
    elif t == "MatchOr":
        result["patterns"] = [
            _pattern_to_dict(p, mutable_vars, redefined, ctx) for p in pattern.patterns
        ]
    elif t == "MatchAs":
        result["name"] = pattern.name  # may be None (wildcard)
        if hasattr(pattern, "pattern") and pattern.pattern is not None:
            result["pattern"] = _pattern_to_dict(pattern.pattern, mutable_vars, redefined, ctx)
    elif t == "MatchSequence":
        result["patterns"] = [
            _pattern_to_dict(p, mutable_vars, redefined, ctx) for p in pattern.patterns
        ]
    elif t == "MatchMapping":
        result["keys"] = [
            _node_to_dict(k, mutable_vars, redefined, ctx) for k in pattern.keys
        ]
        result["patterns"] = [
            _pattern_to_dict(p, mutable_vars, redefined, ctx) for p in pattern.patterns
        ]
        result["rest"] = pattern.rest  # may be None
    elif t == "MatchClass":
        result["cls"] = _node_to_dict(pattern.cls, mutable_vars, redefined, ctx)
        result["patterns"] = [
            _pattern_to_dict(p, mutable_vars, redefined, ctx) for p in pattern.patterns
        ]
        result["kwd_attrs"] = list(pattern.kwd_attrs)
        result["kwd_patterns"] = [
            _pattern_to_dict(p, mutable_vars, redefined, ctx) for p in pattern.kwd_patterns
        ]
    elif t == "MatchStar":
        result["name"] = pattern.name  # may be None (discard)
    return result


def _match_case_to_dict(case, mutable_vars, redefined, ctx):
    """Serialize a match_case node."""
    result = {
        "node_type": "match_case",
        "pattern": _pattern_to_dict(case.pattern, mutable_vars, redefined, ctx),
        "body": [_node_to_dict(s, mutable_vars, redefined, ctx) for s in case.body],
    }
    if case.guard is not None:
        result["guard"] = _node_to_dict(case.guard, mutable_vars, redefined, ctx)
    return result


def main():
    usage = ("Usage: python frontend/ast_dump.py <source.py> [--externals SUMMARIES.json "
             "--root ROOT]\n       python frontend/ast_dump.py --summaries ROOT OUT.json")
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "--summaries":
        write_summaries(args[1], args[2])
        return
    if not (len(args) == 1 or (len(args) == 5 and args[1] == "--externals"
                               and args[3] == "--root")):
        print(usage, file=sys.stderr)
        sys.exit(1)

    file_path = args[0]
    if not os.path.isfile(file_path):
        print(f"Error: File '{file_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    project = None
    if len(args) == 5:
        try:
            project = _load_project_facts(args[2], args[4], file_path)
        except Exception as exc:
            print(f"py2v: project facts not read: {type(exc).__name__}: {exc}", file=sys.stderr)

    try:
        print(process_file(file_path, project))
    except SyntaxError as e:
        print(f"SyntaxError in '{file_path}': {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
