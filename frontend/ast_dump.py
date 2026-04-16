#!/usr/bin/env python3
"""
frontend/ast_dump.py
--------------------
Parses a Python source file into an enriched AST and outputs JSON
for the py2v V-side transpiler.

Enrichments beyond standard ast.parse():
  - _type field on every node
  - mutable_vars, is_void, is_generator on FunctionDef
  - is_class_method, class_name on methods
  - is_mutable on Name nodes
  - redefined_targets on Assign nodes
  - level (nesting depth) on For/While/If
  - docstring_comment on Module
  - __main__ guard rewritten to main() function

Usage:
    python frontend/ast_dump.py <source.py>
"""

import ast
import json
import sys
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set


@dataclass
class AnalysisContext:
    """Per-file analysis results threaded through _node_to_dict.

    Replaces module-level mutable globals to prevent inter-file state
    pollution when processing multiple files in the same interpreter session.
    """
    var_annotations: Dict[str, str] = field(default_factory=dict)
    func_ret_annotations: Dict[str, str] = field(default_factory=dict)

    @staticmethod
    def empty() -> "AnalysisContext":
        """Return a fresh context with no annotations."""
        return AnalysisContext()


# ---------------------------------------------------------------------------
# Analysis passes
# ---------------------------------------------------------------------------

class ScopeTracker(ast.NodeVisitor):
    """Track variable assignments per scope to detect mutability and redefinitions."""

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
        for name in _extract_names(node.target):
            self._record_assign(name, node)
            self.mutable.add(name)
        self.generic_visit(node)

    def visit_AnnAssign(self, node: ast.AnnAssign):
        if node.target:
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
        }
        if (isinstance(node.func, ast.Attribute)
                and node.func.attr in _MUTATING_METHODS
                and isinstance(node.func.value, ast.Name)):
            self.mutable.add(node.func.value.id)
            self._record_assign(node.func.value.id, node)
        self.generic_visit(node)

    def visit_Delete(self, node: ast.Delete):
        """Process del statement - don't mark as mutable since @[translated] relaxes this."""
        self.generic_visit(node)

    def _check_subscript_assign(self, target: ast.AST):
        """x[i] = ... or x[i:j] = ... or x.attr = ... makes x mutable."""
        if isinstance(target, ast.Subscript) and isinstance(target.value, ast.Name):
            self.mutable.add(target.value.id)
            self._record_assign(target.value.id, target)
        elif isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name):
            self.mutable.add(target.value.id)
            self._record_assign(target.value.id, target)
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


def _extract_docstring(tree: ast.Module) -> Optional[str]:
    """Extract module-level docstring."""
    if (tree.body
            and isinstance(tree.body[0], ast.Expr)
            and isinstance(tree.body[0].value, ast.Constant)
            and isinstance(tree.body[0].value.value, str)):
        return tree.body[0].value.value
    return None


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


def _detect_class_methods(tree: ast.Module):
    """Mark methods inside classes with is_class_method and class_name."""
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            for item in node.body:
                if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    item._is_class_method = True
                    item._class_name = node.name


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


def _extract_class_declarations(node: ast.ClassDef) -> Dict[str, str]:
    """Extract field declarations from a class body (AnnAssign, Assign, or __init__)."""
    decls: Dict[str, str] = {}
    for item in node.body:
        if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name):
            type_name = _annotation_to_str(item.annotation)
            decls[item.target.id] = type_name
        elif isinstance(item, ast.Assign):
            # Class-level bare assignment: FIELD = value
            if (len(item.targets) == 1
                    and isinstance(item.targets[0], ast.Name)):
                field_name = item.targets[0].id
                decls[field_name] = _infer_type_from_value(item.value)
        elif isinstance(item, ast.FunctionDef) and item.name == "__init__":
            for stmt in item.body:
                if (isinstance(stmt, ast.AnnAssign)
                        and isinstance(stmt.target, ast.Attribute)
                        and isinstance(stmt.target.value, ast.Name)
                        and stmt.target.value.id == "self"):
                    type_name = _annotation_to_str(stmt.annotation)
                    decls[stmt.target.attr] = type_name
                elif (isinstance(stmt, ast.Assign)
                      and len(stmt.targets) == 1
                      and isinstance(stmt.targets[0], ast.Attribute)
                      and isinstance(stmt.targets[0].value, ast.Name)
                      and stmt.targets[0].value.id == "self"):
                    decls[stmt.targets[0].attr] = ""
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
    result["_type"] = type(node).__name__

    # Location info
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(node, attr):
            val = getattr(node, attr)
            if val is not None:
                result[attr] = val

    # Handle specific node types
    if isinstance(node, ast.Module):
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        docstring = _extract_docstring(node)
        if docstring:
            result["docstring_comment"] = docstring

    elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        result["name"] = node.name

        # Compute mutable vars within this function FIRST
        tracker = ScopeTracker()
        tracker.visit(node)
        func_mutable = tracker.mutable
        result["mutable_vars"] = sorted(func_mutable)

        result["args"] = _arguments_to_dict(node.args, func_mutable)
        # Build a local var_annotation map including parameter annotations so
        # Name nodes inside the function body can get v_annotation hints.
        local_ann = dict(var_annotations)
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

        result["body"] = [_node_to_dict(n, func_mutable, redefined, AnalysisContext(local_ann, ctx.func_ret_annotations)) for n in node.body]
        result["decorator_list"] = [_node_to_dict(d, mutable_vars, redefined, ctx) for d in node.decorator_list]
        result["returns"] = _node_to_dict(node.returns, mutable_vars, redefined, ctx) if node.returns else None
        result["type_comment"] = getattr(node, "type_comment", None)
        result["is_void"] = _is_void_function(node)
        result["is_generator"] = _is_generator(node)
        result["is_class_method"] = getattr(node, "_is_class_method", False)
        result["class_name"] = getattr(node, "_class_name", "")

    elif isinstance(node, ast.ClassDef):
        result["name"] = node.name
        result["bases"] = [_node_to_dict(b, mutable_vars, redefined, ctx) for b in node.bases]
        result["keywords"] = [_keyword_to_dict(kw, mutable_vars, redefined, ctx) for kw in node.keywords]
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["decorator_list"] = [_node_to_dict(d, mutable_vars, redefined, ctx) for d in node.decorator_list]
        result["declarations"] = _extract_class_declarations(node)
        result["class_defaults"] = _extract_class_defaults(node, mutable_vars, redefined, ctx)
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

    elif isinstance(node, ast.AugAssign):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["op"] = {"_type": type(node.op).__name__}
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.AnnAssign):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["annotation"] = _node_to_dict(node.annotation, mutable_vars, redefined, ctx)
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

    elif isinstance(node, ast.Try):
        result["body"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.body]
        result["handlers"] = [_handler_to_dict(h, mutable_vars, redefined, ctx) for h in node.handlers]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.orelse]
        result["finalbody"] = [_node_to_dict(n, mutable_vars, redefined, ctx) for n in node.finalbody]

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

    elif isinstance(node, ast.Expr):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    # Expressions
    elif isinstance(node, ast.BoolOp):
        result["op"] = {"_type": type(node.op).__name__}
        result["values"] = [_node_to_dict(v, mutable_vars, redefined, ctx) for v in node.values]

    elif isinstance(node, ast.NamedExpr):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined, ctx)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.BinOp):
        result["left"] = _node_to_dict(node.left, mutable_vars, redefined, ctx)
        result["op"] = {"_type": type(node.op).__name__}
        result["right"] = _node_to_dict(node.right, mutable_vars, redefined, ctx)

    elif isinstance(node, ast.UnaryOp):
        result["op"] = {"_type": type(node.op).__name__}
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
                    result["body_src"] = ast.unparse(node.body)
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
        result["ops"] = [{"_type": type(op).__name__} for op in node.ops]
        result["comparators"] = [_node_to_dict(c, mutable_vars, redefined, ctx) for c in node.comparators]

    elif isinstance(node, ast.Call):
        result["func"] = _node_to_dict(node.func, mutable_vars, redefined, ctx)
        result["args"] = [_node_to_dict(a, mutable_vars, redefined, ctx) for a in node.args]
        result["keywords"] = [_keyword_to_dict(kw, mutable_vars, redefined, ctx) for kw in node.keywords]
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
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Subscript):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["slice"] = _node_to_dict(node.slice, mutable_vars, redefined, ctx)
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Starred):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined, ctx)
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Name):
        result["id"] = node.id
        result["ctx"] = {"_type": type(node.ctx).__name__}
        result["is_mutable"] = node.id in mutable_vars
        # Attach simple v_annotation if we discovered one during pre-scan
        if node.id in var_annotations:
            result["v_annotation"] = var_annotations[node.id]

    elif isinstance(node, (ast.List, ast.Tuple)):
        result["elts"] = [_node_to_dict(e, mutable_vars, redefined, ctx) for e in node.elts]
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Slice):
        result["lower"] = _node_to_dict(node.lower, mutable_vars, redefined, ctx) if node.lower else None
        result["upper"] = _node_to_dict(node.upper, mutable_vars, redefined, ctx) if node.upper else None
        result["step"] = _node_to_dict(node.step, mutable_vars, redefined, ctx) if node.step else None

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
        return {"_type": "bytes", "value": list(value)}
    if value is Ellipsis:
        return {"_type": "Ellipsis"}
    if isinstance(value, complex):
        return {"_type": "complex", "real": value.real, "imag": value.imag}
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


def _arguments_to_dict(args: ast.arguments, mutable_vars: Set[str]) -> Dict[str, Any]:
    return {
        "_type": "arguments",
        "posonlyargs": [_arg_to_dict(a, mutable_vars) for a in args.posonlyargs],
        "args": [_arg_to_dict(a, mutable_vars) for a in args.args],
        "vararg": _arg_to_dict(args.vararg, mutable_vars) if args.vararg else None,
        "kwonlyargs": [_arg_to_dict(a, mutable_vars) for a in args.kwonlyargs],
        "kw_defaults": [_node_to_dict(d, mutable_vars, {}, AnalysisContext.empty()) if d else None for d in args.kw_defaults],
        "kwarg": _arg_to_dict(args.kwarg, mutable_vars) if args.kwarg else None,
        "defaults": [_node_to_dict(d, mutable_vars, {}, AnalysisContext.empty()) for d in args.defaults],
    }


def _arg_to_dict(arg: ast.arg, mutable_vars: Set[str]) -> Dict[str, Any]:
    result = {
        "_type": "arg",
        "arg": arg.arg,
        "annotation": _node_to_dict(arg.annotation, mutable_vars, {}, AnalysisContext.empty()) if arg.annotation else None,
        "type_comment": getattr(arg, "type_comment", None),
        "is_mutable": arg.arg in mutable_vars,
    }
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
        "_type": "keyword",
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
        "_type": "alias",
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
        "_type": "ExceptHandler",
        "type": _node_to_dict(handler.type, mutable_vars, redefined, ctx) if handler.type else None,
        "name": handler.name,
        "body": [_node_to_dict(n, mutable_vars, redefined, ctx) for n in handler.body],
    }
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
        "_type": "withitem",
        "context_expr": _node_to_dict(item.context_expr, mutable_vars, redefined, ctx),
        "optional_vars": _node_to_dict(item.optional_vars, mutable_vars, redefined, ctx) if item.optional_vars else None,
    }


def _comprehension_to_dict(comp: ast.comprehension, mutable_vars: Set[str],
                           redefined: Dict[int, List[str]],
                           ctx: Optional[AnalysisContext] = None) -> Dict[str, Any]:
    if ctx is None:
        ctx = AnalysisContext.empty()
    return {
        "_type": "comprehension",
        "target": _node_to_dict(comp.target, mutable_vars, redefined, ctx),
        "iter": _node_to_dict(comp.iter, mutable_vars, redefined, ctx),
        "ifs": [_node_to_dict(i, mutable_vars, redefined, ctx) for i in comp.ifs],
        "is_async": bool(comp.is_async),
    }


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def process_file(file_path: str) -> str:
    """Parse, analyze, and return enriched JSON AST."""
    with open(file_path, "r", encoding="utf-8") as f:
        source = f.read()

    tree = ast.parse(source, filename=file_path)

    # Rewrite __main__ guard
    tree = _rewrite_main_guard(tree)

    # Detect class methods
    _detect_class_methods(tree)

    # Detect nesting levels
    _detect_nesting_levels(tree)

    # Track mutability
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
    )

    result = _node_to_dict(tree, mutable_vars, redefined, ctx)
    return json.dumps(result)


def main():
    if len(sys.argv) != 2:
        print("Usage: python frontend/ast_dump.py <source.py>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.isfile(file_path):
        print(f"Error: File '{file_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    try:
        print(process_file(file_path))
    except SyntaxError as e:
        print(f"SyntaxError in '{file_path}': {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
