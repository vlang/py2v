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
from typing import Any, Dict, List, Optional, Set


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


def _extract_class_declarations(node: ast.ClassDef) -> Dict[str, str]:
    """Extract field declarations from a class body (AnnAssign in __init__ or class body)."""
    decls: Dict[str, str] = {}
    for item in node.body:
        if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name):
            type_name = _annotation_to_str(item.annotation)
            decls[item.target.id] = type_name
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
    return ""


# ---------------------------------------------------------------------------
# AST to JSON serializer
# ---------------------------------------------------------------------------

def _node_to_dict(node: ast.AST, mutable_vars: Set[str],
                  redefined: Dict[int, List[str]]) -> Dict[str, Any]:
    """Convert an AST node to a JSON-serializable dict."""
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
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
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
        result["body"] = [_node_to_dict(n, func_mutable, redefined) for n in node.body]
        result["decorator_list"] = [_node_to_dict(d, mutable_vars, redefined) for d in node.decorator_list]
        result["returns"] = _node_to_dict(node.returns, mutable_vars, redefined) if node.returns else None
        result["type_comment"] = getattr(node, "type_comment", None)
        result["is_void"] = _is_void_function(node)
        result["is_generator"] = _is_generator(node)
        result["is_class_method"] = getattr(node, "_is_class_method", False)
        result["class_name"] = getattr(node, "_class_name", "")

    elif isinstance(node, ast.ClassDef):
        result["name"] = node.name
        result["bases"] = [_node_to_dict(b, mutable_vars, redefined) for b in node.bases]
        result["keywords"] = [_keyword_to_dict(kw, mutable_vars, redefined) for kw in node.keywords]
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
        result["decorator_list"] = [_node_to_dict(d, mutable_vars, redefined) for d in node.decorator_list]
        result["declarations"] = _extract_class_declarations(node)
        # Extract class-level docstring
        if (node.body
                and isinstance(node.body[0], ast.Expr)
                and isinstance(node.body[0].value, ast.Constant)
                and isinstance(node.body[0].value.value, str)):
            result["docstring_comment"] = node.body[0].value.value

    elif isinstance(node, ast.Return):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined) if node.value else None

    elif isinstance(node, ast.Delete):
        result["targets"] = [_node_to_dict(t, mutable_vars, redefined) for t in node.targets]

    elif isinstance(node, ast.Assign):
        result["targets"] = [_node_to_dict(t, mutable_vars, redefined) for t in node.targets]
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)
        result["type_comment"] = getattr(node, "type_comment", None)
        redef = redefined.get(id(node), [])
        if redef:
            result["redefined_targets"] = redef

    elif isinstance(node, ast.AugAssign):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined)
        result["op"] = {"_type": type(node.op).__name__}
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)

    elif isinstance(node, ast.AnnAssign):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined)
        result["annotation"] = _node_to_dict(node.annotation, mutable_vars, redefined)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined) if node.value else None
        result["simple"] = node.simple

    elif isinstance(node, (ast.For, ast.AsyncFor)):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined)
        result["iter"] = _node_to_dict(node.iter, mutable_vars, redefined)
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.orelse]
        result["type_comment"] = getattr(node, "type_comment", None)
        result["level"] = getattr(node, "_level", 0)

    elif isinstance(node, ast.While):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined)
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.orelse]
        result["level"] = getattr(node, "_level", 0)

    elif isinstance(node, ast.If):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined)
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.orelse]
        result["level"] = getattr(node, "_level", 0)

    elif isinstance(node, (ast.With, ast.AsyncWith)):
        result["items"] = [_withitem_to_dict(item, mutable_vars, redefined) for item in node.items]
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
        result["type_comment"] = getattr(node, "type_comment", None)

    elif isinstance(node, ast.Raise):
        result["exc"] = _node_to_dict(node.exc, mutable_vars, redefined) if node.exc else None
        result["cause"] = _node_to_dict(node.cause, mutable_vars, redefined) if node.cause else None

    elif isinstance(node, ast.Try):
        result["body"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.body]
        result["handlers"] = [_handler_to_dict(h, mutable_vars, redefined) for h in node.handlers]
        result["orelse"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.orelse]
        result["finalbody"] = [_node_to_dict(n, mutable_vars, redefined) for n in node.finalbody]

    elif isinstance(node, ast.Assert):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined)
        result["msg"] = _node_to_dict(node.msg, mutable_vars, redefined) if node.msg else None

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

    elif isinstance(node, ast.Expr):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)

    # Expressions
    elif isinstance(node, ast.BoolOp):
        result["op"] = {"_type": type(node.op).__name__}
        result["values"] = [_node_to_dict(v, mutable_vars, redefined) for v in node.values]

    elif isinstance(node, ast.NamedExpr):
        result["target"] = _node_to_dict(node.target, mutable_vars, redefined)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)

    elif isinstance(node, ast.BinOp):
        result["left"] = _node_to_dict(node.left, mutable_vars, redefined)
        result["op"] = {"_type": type(node.op).__name__}
        result["right"] = _node_to_dict(node.right, mutable_vars, redefined)

    elif isinstance(node, ast.UnaryOp):
        result["op"] = {"_type": type(node.op).__name__}
        result["operand"] = _node_to_dict(node.operand, mutable_vars, redefined)

    elif isinstance(node, ast.Lambda):
        result["args"] = _arguments_to_dict(node.args, mutable_vars)
        result["body"] = _node_to_dict(node.body, mutable_vars, redefined)

    elif isinstance(node, ast.IfExp):
        result["test"] = _node_to_dict(node.test, mutable_vars, redefined)
        result["body"] = _node_to_dict(node.body, mutable_vars, redefined)
        result["orelse"] = _node_to_dict(node.orelse, mutable_vars, redefined)

    elif isinstance(node, ast.Dict):
        result["keys"] = [_node_to_dict(k, mutable_vars, redefined) if k else None for k in node.keys]
        result["values"] = [_node_to_dict(v, mutable_vars, redefined) for v in node.values]

    elif isinstance(node, ast.Set):
        result["elts"] = [_node_to_dict(e, mutable_vars, redefined) for e in node.elts]

    elif isinstance(node, (ast.ListComp, ast.SetComp, ast.GeneratorExp)):
        result["elt"] = _node_to_dict(node.elt, mutable_vars, redefined)
        result["generators"] = [_comprehension_to_dict(g, mutable_vars, redefined) for g in node.generators]

    elif isinstance(node, ast.DictComp):
        result["key"] = _node_to_dict(node.key, mutable_vars, redefined)
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)
        result["generators"] = [_comprehension_to_dict(g, mutable_vars, redefined) for g in node.generators]

    elif isinstance(node, ast.Await):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)

    elif isinstance(node, ast.Yield):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined) if node.value else None

    elif isinstance(node, ast.YieldFrom):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)

    elif isinstance(node, ast.Compare):
        result["left"] = _node_to_dict(node.left, mutable_vars, redefined)
        result["ops"] = [{"_type": type(op).__name__} for op in node.ops]
        result["comparators"] = [_node_to_dict(c, mutable_vars, redefined) for c in node.comparators]

    elif isinstance(node, ast.Call):
        result["func"] = _node_to_dict(node.func, mutable_vars, redefined)
        result["args"] = [_node_to_dict(a, mutable_vars, redefined) for a in node.args]
        result["keywords"] = [_keyword_to_dict(kw, mutable_vars, redefined) for kw in node.keywords]

    elif isinstance(node, ast.FormattedValue):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)
        result["conversion"] = node.conversion
        result["format_spec"] = _node_to_dict(node.format_spec, mutable_vars, redefined) if node.format_spec else None

    elif isinstance(node, ast.JoinedStr):
        result["values"] = [_node_to_dict(v, mutable_vars, redefined) for v in node.values]

    elif isinstance(node, ast.Constant):
        result["value"] = _constant_value(node.value)
        result["kind"] = node.kind
        # Mark float constants with v_annotation for type-aware transpilation
        if isinstance(node.value, float):
            result["v_annotation"] = "float"

    elif isinstance(node, ast.Attribute):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)
        result["attr"] = node.attr
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Subscript):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)
        result["slice"] = _node_to_dict(node.slice, mutable_vars, redefined)
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Starred):
        result["value"] = _node_to_dict(node.value, mutable_vars, redefined)
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Name):
        result["id"] = node.id
        result["ctx"] = {"_type": type(node.ctx).__name__}
        result["is_mutable"] = node.id in mutable_vars

    elif isinstance(node, (ast.List, ast.Tuple)):
        result["elts"] = [_node_to_dict(e, mutable_vars, redefined) for e in node.elts]
        result["ctx"] = {"_type": type(node.ctx).__name__}

    elif isinstance(node, ast.Slice):
        result["lower"] = _node_to_dict(node.lower, mutable_vars, redefined) if node.lower else None
        result["upper"] = _node_to_dict(node.upper, mutable_vars, redefined) if node.upper else None
        result["step"] = _node_to_dict(node.step, mutable_vars, redefined) if node.step else None

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


def _arguments_to_dict(args: ast.arguments, mutable_vars: Set[str]) -> Dict[str, Any]:
    return {
        "_type": "arguments",
        "posonlyargs": [_arg_to_dict(a, mutable_vars) for a in args.posonlyargs],
        "args": [_arg_to_dict(a, mutable_vars) for a in args.args],
        "vararg": _arg_to_dict(args.vararg, mutable_vars) if args.vararg else None,
        "kwonlyargs": [_arg_to_dict(a, mutable_vars) for a in args.kwonlyargs],
        "kw_defaults": [_node_to_dict(d, mutable_vars, {}) if d else None for d in args.kw_defaults],
        "kwarg": _arg_to_dict(args.kwarg, mutable_vars) if args.kwarg else None,
        "defaults": [_node_to_dict(d, mutable_vars, {}) for d in args.defaults],
    }


def _arg_to_dict(arg: ast.arg, mutable_vars: Set[str]) -> Dict[str, Any]:
    result = {
        "_type": "arg",
        "arg": arg.arg,
        "annotation": _node_to_dict(arg.annotation, mutable_vars, {}) if arg.annotation else None,
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
                     redefined: Dict[int, List[str]]) -> Dict[str, Any]:
    result = {
        "_type": "keyword",
        "arg": kw.arg,
        "value": _node_to_dict(kw.value, mutable_vars, redefined),
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
                     redefined: Dict[int, List[str]]) -> Dict[str, Any]:
    result = {
        "_type": "ExceptHandler",
        "type": _node_to_dict(handler.type, mutable_vars, redefined) if handler.type else None,
        "name": handler.name,
        "body": [_node_to_dict(n, mutable_vars, redefined) for n in handler.body],
    }
    for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset"):
        if hasattr(handler, attr):
            val = getattr(handler, attr)
            if val is not None:
                result[attr] = val
    return result


def _withitem_to_dict(item: ast.withitem, mutable_vars: Set[str],
                      redefined: Dict[int, List[str]]) -> Dict[str, Any]:
    return {
        "_type": "withitem",
        "context_expr": _node_to_dict(item.context_expr, mutable_vars, redefined),
        "optional_vars": _node_to_dict(item.optional_vars, mutable_vars, redefined) if item.optional_vars else None,
    }


def _comprehension_to_dict(comp: ast.comprehension, mutable_vars: Set[str],
                           redefined: Dict[int, List[str]]) -> Dict[str, Any]:
    return {
        "_type": "comprehension",
        "target": _node_to_dict(comp.target, mutable_vars, redefined),
        "iter": _node_to_dict(comp.iter, mutable_vars, redefined),
        "ifs": [_node_to_dict(i, mutable_vars, redefined) for i in comp.ifs],
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

    # Serialize
    result = _node_to_dict(tree, mutable_vars, redefined)
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
