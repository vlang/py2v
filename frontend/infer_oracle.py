"""Execution-based falsification oracle for ``infer.py`` (CPython 3.9+).

Only explicitly supplied programs are executed. Each gets a fresh interpreter,
its normal script globals and import directory, inherited working directory,
discarded stdout/stderr, and a wall-clock timeout (10 seconds by default). This
is process isolation, not a security sandbox. Do not point it at untrusted code.

Observations are made on call, line, and return events in the supplied file,
including newly started threads and registered atexit callbacks. A line event precedes that line's execution;
short-lived intermediate assignments on the same line need not be observed.
Real RETURN_* instructions distinguish returns from exception unwinds and
YIELD_* suspensions. Generator/coroutine resume events are not fresh calls.

Runtime inspection defaults: depth 4, first 32 elements per exact builtin
container, and 256 visited objects per value. Iterators are never consumed.
Depth/cycle/budget cutoffs are recorded as unknown observations and cannot
produce violations for the uninspected part. Thus a clean run is evidence for
sampled executions, not a proof. Builtin subclasses are inspected nominally,
without invoking their iteration, repr, descriptors, or conversion hooks.

Same-line scopes which cannot be mapped uniquely are skipped and reported.
CPython 3.12+ inlined comprehensions have no frame. Their possibly shadowed
locals are skipped on the comprehension's source lines and reported; the
oracle does not misattribute those temporary values to enclosing bindings.
Function and class objects are identified without calling them. Their latent
argument/return types, and unconsumed iterator element types, are unobserved.

Examples::

    python3 frontend/infer_oracle.py tests/cases/*.py
    python3 frontend/infer_oracle.py --missed --timeout 20 example.py

Exit bits: 1 = inferred contradiction, 2 = assumption/annotation mismatch,
4 = program/oracle error; multiple bits can be set simultaneously.
The ``represented`` layer is *not* checked: it describes the emitter's selected
storage type, not a claim about the type of a Python runtime object.
``--api MANIFEST.json`` supplies the same passive signatures to inference in
its child process; it does not load or execute the named library for inference.

``admits(types, inferred_id, observed)`` is usable independently. Observed types
are nested semantic dictionaries; inferred types use infer's interned table.
Observed unions require *every* member to be admitted; inferred unions accept
any admitting member. Primitive bool and int are deliberately distinct. Lists,
sets and mappings are compared by their observed contents (covariantly); this
checks the actual value, not whether mutable type annotations are assignable.
Per the requested empty-container rule, () is admitted by every tuple type,
including a nonempty fixed tuple. This is deliberate oracle leniency: a
backend still must not treat an empty tuple as a populated generated struct.
Nonempty fixed tuples require the correct arity. Child processes started by
the program are not instrumented; daemon threads follow normal shutdown.
"""
from __future__ import annotations

import argparse
import atexit
import ast
import dis
import inspect
import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import tokenize
import traceback
import types as pytypes
from collections import Counter
from dataclasses import dataclass
from typing import Any, Callable, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple

import infer
import symbols

Type = Dict[str, Any]
MAX_DEPTH = 4
MAX_ELEMENTS = 32
MAX_NODES = 256
_UNKNOWN = {"k": "unknown", "why": "runtime type information unavailable"}
_NEVER = {"k": "never"}
_ITERATOR_NAMES = {
    "list_iterator", "list_reverseiterator", "tuple_iterator", "str_iterator",
    "bytes_iterator", "bytearray_iterator", "set_iterator", "dict_keyiterator",
    "dict_valueiterator", "dict_itemiterator", "dict_reversekeyiterator",
    "dict_reversevalueiterator", "dict_reverseitemiterator", "range_iterator",
    "longrange_iterator", "zip", "enumerate", "map", "filter", "reversed",
    "callable_iterator", "iterator",
}
_DICT_VIEWS = ((type({}.keys()), "dict_keys"), (type({}.values()), "dict_values"), (type({}.items()), "dict_items"))


def _key(t: Type) -> str:
    """Canonical structural key, including nominal inheritance evidence."""
    return json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def _unknown(why: str) -> Type:
    return {"k": "unknown", "why": why}


def _type_attr(cls: type, name: str) -> Any:
    # Invoke type's own C-level descriptor, bypassing a metaclass property.
    return type.__dict__[name].__get__(cls, type(cls))


def _is_class(value: Any) -> bool:
    return any(base is type for base in _type_attr(type(value), "__mro__"))


def _nominal_name(cls: type) -> str:
    module = _type_attr(cls, "__module__")
    name = _type_attr(cls, "__qualname__")
    if type(module) is not str:
        module = "<unknown-module>"
    return name if module == "builtins" else module + "." + name


def _join(a: Type, b: Type) -> Type:
    """Join observations, retaining every sampled alternative, without widening."""
    if a["k"] == "never":
        return b
    if b["k"] == "never" or _key(a) == _key(b):
        return a
    if a["k"] == b["k"]:
        kind = a["k"]
        if kind in ("list", "set", "tuple_of"):
            return {"k": kind, "elem": _join(a["elem"], b["elem"])}
        if kind == "dict":
            return {"k": kind, "key": _join(a["key"], b["key"]),
                    "value": _join(a["value"], b["value"])}
        if kind == "tuple" and len(a["elems"]) == len(b["elems"]):
            return {"k": kind, "elems": [_join(x, y) for x, y in zip(a["elems"], b["elems"])]}
    members: Dict[str, Type] = {}
    for item in (a, b):
        for member in item.get("members", [item]) if item["k"] == "union" else [item]:
            members[_key(member)] = member
    return {"k": "union", "members": [members[k] for k in sorted(members)]}


def _join_all(values: Iterable[Type]) -> Type:
    result: Type = _NEVER
    for value in values:
        result = _join(result, value)
    return result


def _normal_name(name: str) -> str:
    name = {"_io._TextIOBase": "io.TextIOBase", "_io._BufferedIOBase": "io.BufferedIOBase",
            "_io._RawIOBase": "io.RawIOBase", "_io._IOBase": "io.IOBase"}.get(name, name)
    if name.startswith("builtins."):
        return name[9:]
    return name


def _nominal_match(expected: Mapping[str, Any], observed: Type) -> bool:
    eb = expected.get("class_binding")
    for candidate in [observed] + observed.get("_bases", []):
        ob = candidate.get("class_binding")
        if eb is not None and ob is not None and eb == ob:
            return True
        if eb is None and _normal_name(str(expected.get("name", ""))) == _normal_name(str(candidate.get("name", ""))):
            return True
    return False


def admits(table: Sequence[Mapping[str, Any]], inferred: int, observed: Type) -> bool:
    """Return false only for a sampled value incompatible with the inferred type.

    Unknown/dynamic on the inference side admit all values. Unknown on the
    observation side means an inspection cutoff, and leaves that subtree
    untested. Empty runtime containers therefore impose no element constraint.
    Nominal observations include an internal ``_bases`` list to admit actual
    subclasses (e.g. PosixPath where Path was inferred). It does not collapse
    exact primitive bool into int. Runtime callable signatures are not guessed.
    """
    expected = table[inferred]
    ik, ok = expected["k"], observed["k"]
    if ik in ("unknown", "dynamic") or ok in ("unknown", "dynamic", "never"):
        return True
    if ok == "union":
        return all(admits(table, inferred, member) for member in observed["members"])
    if ik == "union":
        return any(admits(table, member, observed) for member in expected["members"])
    if ik == "never":
        return False
    if ik in ("tuple", "tuple_of") and ok == "tuple" and not observed["elems"]:
        return True
    if ik == "instance" and expected.get("class_binding") is None:
        name = _normal_name(str(expected.get("name", "")))
        args = expected.get("args", [])
        if name in ("collections.abc.Mapping", "typing.Mapping") and ok == "dict":
            return not args or len(args) == 2 and admits(table, args[0], observed["key"]) and admits(table, args[1], observed["value"])
        sequence = name in ("collections.abc.Sequence", "typing.Sequence")
        iterable = name in ("collections.abc.Iterable", "typing.Iterable")
        if sequence or iterable:
            elem: Optional[Type] = None
            if ok in ("list", "tuple_of") or iterable and ok == "set":
                elem = observed["elem"]
            elif ok == "tuple":
                elem = _join_all(observed["elems"])
            elif ok in ("str", "bytes"):
                elem = {"k": "str" if ok == "str" else "int"}
            elif iterable and ok == "dict":
                elem = observed["key"]
            if elem is not None:
                return not args or admits(table, args[0], elem)
    if ik == "tuple_of" and ok == "tuple":
        return all(admits(table, expected["elem"], x) for x in observed["elems"])
    if ik == "tuple" and ok == "tuple_of":
        # A capped observation has an unknown tail and no reliable fixed shape.
        return observed.get("_length") == len(expected["elems"]) and all(
            admits(table, x, y) for x, y in zip(expected["elems"], observed.get("_prefix", [])))
    if ik != ok:
        return False
    if ik in ("none", "bool", "int", "float", "str", "bytes"):
        return True
    if ik in ("list", "set", "tuple_of"):
        return admits(table, expected["elem"], observed["elem"])
    if ik == "dict":
        return admits(table, expected["key"], observed["key"]) and admits(table, expected["value"], observed["value"])
    if ik == "tuple":
        return len(expected["elems"]) == len(observed["elems"]) and all(
            admits(table, x, y) for x, y in zip(expected["elems"], observed["elems"]))
    if ik in ("instance", "class"):
        ename = _normal_name(str(expected.get("name", "")))
        oname = _normal_name(str(observed.get("name", "")))
        iterator_alias = ename in ("collections.abc.Iterable", "collections.abc.Iterator", "typing.Iterable", "typing.Iterator") and oname in (
            "range", "collections.abc.Iterator", "collections.abc.Generator")
        if not iterator_alias and not _nominal_match(expected, observed):
            return False
        if ik == "instance":
            ea, oa = expected.get("args", []), observed.get("args", [])
            # No observed type arguments means they were not inspectable.
            if oa and all(x["k"] in ("unknown", "dynamic") for x in oa):
                return True
            if iterator_alias and len(ea) == 1 and oa:
                return admits(table, ea[0], oa[0])
            return not oa or not ea or len(ea) == len(oa) and all(
                admits(table, x, y) for x, y in zip(ea, oa))
        return True
    if ik == "module":
        return expected["name"] == observed["name"] or expected["name"] == "os.path" and observed["name"] == os.path.__name__
    if ik == "callable":
        eb, ob = expected.get("func_binding"), observed.get("func_binding")
        return eb is None or ob is None or eb == ob
    if ik == "typevar":
        # A TypeVar is a constraint placeholder, not a runtime representation.
        return True
    return False


def render_observed(t: Type) -> str:
    k = t["k"]
    if k in ("unknown", "dynamic"):
        return k + "(" + str(t.get("why", "")) + ")"
    if k in ("list", "set", "tuple_of"):
        return k + "[" + render_observed(t["elem"]) + "]"
    if k == "dict":
        return "dict[" + render_observed(t["key"]) + ", " + render_observed(t["value"]) + "]"
    if k in ("tuple", "union"):
        return k + "[" + ", ".join(render_observed(x) for x in t["elems" if k == "tuple" else "members"]) + "]"
    if k in ("instance", "class"):
        text = str(t["name"])
        if t.get("args"):
            text += "[" + ", ".join(render_observed(x) for x in t["args"]) + "]"
        return "class[" + text + "]" if k == "class" else text
    if k == "callable":
        return "callable[unobserved signature]"
    if k == "module":
        return "module[" + t["name"] + "]"
    return k


def _concrete(t: Type) -> bool:
    if t["k"] in ("never", "unknown", "dynamic", "union", "typevar", "callable"):
        return False
    for key in ("elem", "key", "value", "ret"):
        if key in t and not _concrete(t[key]):
            return False
    for key in ("elems", "args", "params"):
        if key in t and not all(_concrete(x) for x in t[key]):
            return False
    return True


@dataclass
class ScopeNode:
    scope: int
    node: ast.AST
    code_name: str
    first_line: int
    end_line: int
    column: int
    end_column: int


class CodeMap:
    """Map actual compiled code identities to the provided lexical scopes."""

    def __init__(self, tree: ast.Module, table: Any, code: pytypes.CodeType) -> None:
        self.table = table
        self.scope_for_code: Dict[pytypes.CodeType, int] = {}
        self.node_for_scope: Dict[int, ScopeNode] = {}
        self.ambiguous: Set[str] = set()
        self.instructions: Dict[pytypes.CodeType, Dict[int, dis.Instruction]] = {}
        self.inline: Dict[int, List[Tuple[int, int, Set[str]]]] = {}
        self.inline_scopes: List[int] = []
        scope_nodes: List[ScopeNode] = []
        module_scope = next(s.id for s in table.scopes if s.kind == "module")
        self.scope_for_code[code] = module_scope
        kinds = {ast.Lambda: "<lambda>", ast.ListComp: "<listcomp>",
                 ast.SetComp: "<setcomp>", ast.DictComp: "<dictcomp>", ast.GeneratorExp: "<genexpr>"}
        for node in ast.walk(tree):
            sid = getattr(node, "_scope_id", None)
            if sid is None or isinstance(node, ast.Module):
                continue
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                name = node.name
                first = min([node.lineno] + [d.lineno for d in node.decorator_list])
            elif type(node) in kinds:
                name = kinds[type(node)]
                first = node.lineno
            else:
                continue
            item = ScopeNode(sid, node, name, first, getattr(node, "end_lineno", node.lineno) or node.lineno,
                             node.col_offset, getattr(node, "end_col_offset", node.col_offset) or node.col_offset)
            scope_nodes.append(item)
            self.node_for_scope[sid] = item
        used: Set[int] = {module_scope}

        def walk(parent: pytypes.CodeType) -> None:
            parent_scope = self.scope_for_code.get(parent)
            for child in parent.co_consts:
                if not isinstance(child, pytypes.CodeType):
                    continue
                candidates = [s for s in scope_nodes if s.scope not in used and s.code_name == child.co_name and s.first_line == child.co_firstlineno]
                if parent_scope is not None:
                    direct = [s for s in candidates if self._code_parent(s.scope) == parent_scope]
                    if direct:
                        candidates = direct
                if len(candidates) > 1 and hasattr(child, "co_positions"):
                    # Ignore artificial RESUME/COPY_FREE_VARS positions (column 0).
                    positions = [(i.positions.lineno, i.positions.col_offset) for i in dis.get_instructions(child)
                                 if getattr(i, "positions", None) is not None
                                 and i.opname not in ("RESUME", "COPY_FREE_VARS", "RETURN_GENERATOR", "POP_TOP")
                                 and i.positions.lineno is not None and i.positions.col_offset is not None]
                    if positions:
                        line, column = positions[0]
                        containing = [s for s in candidates if s.node.lineno <= line <= s.end_line
                                      and (line != s.node.lineno or column >= s.column)
                                      and (line != s.end_line or column < s.end_column)]
                        if len(containing) == 1:
                            candidates = containing
                if len(candidates) == 1:
                    item = candidates[0]
                    self.scope_for_code[child] = item.scope
                    used.add(item.scope)
                else:
                    self.ambiguous.add(child.co_name + ":" + str(child.co_firstlineno))
                walk(child)

        walk(code)
        for item in scope_nodes:
            if item.scope in used or not isinstance(item.node, (ast.ListComp, ast.SetComp, ast.DictComp)):
                continue
            parent = table.scopes[item.scope].parent
            while parent is not None and parent not in used:
                parent = table.scopes[parent].parent
            if parent is not None:
                names = {b.name for b in table.bindings if b.scope == item.scope}
                self.inline.setdefault(parent, []).append((item.node.lineno, item.end_line, names))
                self.inline_scopes.append(item.scope)

    def _code_parent(self, sid: int) -> Optional[int]:
        parent = self.table.scopes[sid].parent
        while parent is not None and self.table.scopes[parent].kind == "type_params":
            parent = self.table.scopes[parent].parent
        return parent

    def instruction(self, frame: pytypes.FrameType) -> Optional[dis.Instruction]:
        code = frame.f_code
        if code not in self.instructions:
            self.instructions[code] = {i.offset: i for i in dis.get_instructions(code)}
        return self.instructions[code].get(frame.f_lasti)

    def actual_return(self, frame: pytypes.FrameType) -> bool:
        instruction = self.instruction(frame)
        return instruction is not None and instruction.opname in (
            "RETURN_VALUE", "RETURN_CONST", "INSTRUMENTED_RETURN_VALUE", "INSTRUMENTED_RETURN_CONST")

    def initial_call(self, frame: pytypes.FrameType) -> bool:
        if not frame.f_code.co_flags & (inspect.CO_GENERATOR | inspect.CO_COROUTINE | inspect.CO_ASYNC_GENERATOR):
            return True
        if frame.f_lasti <= 0:
            return True
        instruction = self.instruction(frame)
        return instruction is not None and instruction.opname.startswith("RESUME") and instruction.arg == 0


class RuntimeTypes:
    def __init__(self, code_map: CodeMap, functions: Mapping[int, Mapping[str, Any]],
                 class_ids: Dict[int, int], class_names: Mapping[int, str],
                 depth: int, elements: int, nodes: int) -> None:
        self.code_map = code_map
        self.functions = functions
        self.class_ids = class_ids
        self.class_names = class_names
        self.depth, self.elements, self.nodes = depth, elements, nodes
        self.cutoffs: Counter[str] = Counter()

    def of(self, value: Any) -> Type:
        budget = [self.nodes]
        return self._of(value, 0, set(), budget)

    def _nominal(self, cls: type, kind: str) -> Type:
        bid = self.class_ids.get(id(cls))
        result: Type = {"k": kind, "class_binding": bid,
                        "name": self.class_names.get(bid, _nominal_name(cls))}
        if kind == "instance":
            result["args"] = []
        bases: List[Type] = []
        for base in _type_attr(cls, "__mro__")[1:]:
            bb = self.class_ids.get(id(base))
            bases.append({"class_binding": bb, "name": self.class_names.get(bb, _nominal_name(base))})
        if bases:
            result["_bases"] = bases
        return result

    def _cutoff(self, reason: str) -> Type:
        self.cutoffs[reason] += 1
        return _unknown(reason)

    def _of(self, value: Any, depth: int, seen: Set[int], budget: List[int]) -> Type:
        budget[0] -= 1
        if budget[0] < 0:
            return self._cutoff("runtime inspection node budget")
        cls = type(value)
        for primitive, kind in ((type(None), "none"), (bool, "bool"), (int, "int"), (float, "float"), (str, "str"), (bytes, "bytes")):
            if cls is primitive:
                return {"k": kind}
        if depth >= self.depth:
            return self._cutoff("runtime inspection depth limit")
        if id(value) in seen:
            return self._cutoff("cyclic runtime value")
        if any(cls is builtin for builtin in (list, tuple, dict, set, frozenset)):
            nested = set(seen)
            nested.add(id(value))
            if cls is dict:
                keys: List[Type] = []
                vals: List[Type] = []
                for index, (key, val) in enumerate(dict.items(value)):
                    if index >= self.elements:
                        self.cutoffs["runtime element sample limit"] += 1
                        break
                    keys.append(self._of(key, depth + 1, nested, budget))
                    vals.append(self._of(val, depth + 1, nested, budget))
                return {"k": "dict", "key": _join_all(keys), "value": _join_all(vals)}
            vals = []
            iterator = iter(value)  # exact builtin containers only
            for index, val in enumerate(iterator):
                if index >= self.elements:
                    self.cutoffs["runtime element sample limit"] += 1
                    break
                vals.append(self._of(val, depth + 1, nested, budget))
            if cls is tuple:
                if len(value) > self.elements:
                    # Preserve positions and full arity using unknown tail entries.
                    # Huge tuples are represented as tuple_of to bound the report.
                    if len(value) <= self.nodes:
                        vals.extend([self._cutoff("runtime tuple sample limit")] * (len(value) - len(vals)))
                        return {"k": "tuple", "elems": vals}
                    self.cutoffs["runtime tuple sample limit"] += 1
                    return {"k": "tuple_of", "elem": _join_all(vals), "_length": len(value), "_prefix": vals}
                return {"k": "tuple", "elems": vals}
            if cls is frozenset:
                return {"k": "instance", "class_binding": None, "name": "frozenset", "args": [_join_all(vals)]}
            return {"k": "list" if cls is list else "set", "elem": _join_all(vals)}
        view_name = next((name for view_type, name in _DICT_VIEWS if cls is view_type), None)
        if view_name is not None:
            nested = set(seen)
            nested.add(id(value))
            vals = []
            for index, val in enumerate(iter(value)):
                if index >= self.elements:
                    self.cutoffs["runtime element sample limit"] += 1
                    break
                vals.append(self._of(val, depth + 1, nested, budget))
            return {"k": "instance", "class_binding": None, "name": view_name,
                    "args": [_join_all(vals)],
                    "_bases": [{"class_binding": None, "name": "collections.abc.Iterable"}]}
        if _is_class(value):
            return self._nominal(value, "class")
        if cls is pytypes.ModuleType:
            name = pytypes.ModuleType.__getattribute__(value, "__dict__").get("__name__")
            return {"k": "module", "name": name} if type(name) is str else _unknown("runtime module name unavailable")
        if cls is pytypes.FunctionType or cls is pytypes.MethodType:
            function = value.__func__ if cls is pytypes.MethodType else value
            scope = self.code_map.scope_for_code.get(function.__code__)
            fact = self.functions.get(scope, {})
            return {"k": "callable", "params": [], "ret": _UNKNOWN, "func_binding": fact.get("binding")}
        if cls is pytypes.BuiltinFunctionType or cls is pytypes.BuiltinMethodType:
            return {"k": "callable", "params": [], "ret": _UNKNOWN, "func_binding": None}
        if cls is range:
            return {"k": "instance", "class_binding": None, "name": "range", "args": [{"k": "int"}]}
        if cls is pytypes.GeneratorType:
            return {"k": "instance", "class_binding": None, "name": "collections.abc.Generator", "args": [_UNKNOWN, _UNKNOWN, _UNKNOWN]}
        if cls is pytypes.CoroutineType:
            return {"k": "instance", "class_binding": None, "name": "collections.abc.Coroutine", "args": [_UNKNOWN]}
        if cls is pytypes.AsyncGeneratorType:
            return {"k": "instance", "class_binding": None, "name": "collections.abc.AsyncGenerator", "args": [_UNKNOWN, _UNKNOWN]}
        if _type_attr(cls, "__module__") == "builtins" and _type_attr(cls, "__name__") in _ITERATOR_NAMES:
            return {"k": "instance", "class_binding": None, "name": "collections.abc.Iterator", "args": [_UNKNOWN]}
        return self._nominal(cls, "instance")


class Observer:
    def __init__(self, filename: str, tree: ast.Module, table: Any, facts: Dict[str, Any],
                 code: pytypes.CodeType, depth: int, elements: int, nodes: int) -> None:
        self.filename = filename
        self.table, self.facts = table, facts
        self.code_map = CodeMap(tree, table, code)
        self.functions = {f["scope"]: f for f in facts["functions"]}
        self.bindings = {b["id"]: b for b in facts["bindings"]}
        self.by_scope: Dict[int, Dict[str, int]] = {s.id: {} for s in table.scopes}
        self.module_scope = next(s.id for s in table.scopes if s.kind == "module")
        self.class_ids: Dict[int, int] = {}
        self.class_names: Dict[int, str] = {}
        self.observations: Dict[Tuple[str, int, str], Dict[str, Any]] = {}
        self.skipped_scopes: Set[str] = set()
        self.inline_skips: Set[Tuple[int, str]] = set()
        self.trace_errors: List[str] = []
        self.lock = threading.RLock()
        for b in table.bindings:
            self.by_scope[b.scope][b.name] = b.id
            if b.kind == "class":
                self.class_names[b.id] = b.name
        for node in ast.walk(tree):
            bid, sid = getattr(node, "_binding", None), getattr(node, "_scope", None)
            if bid is None or sid is None:
                continue
            if isinstance(node, ast.ClassDef):
                self.class_names[bid] = node.name
            name = node.id if isinstance(node, ast.Name) else node.arg if isinstance(node, ast.arg) else None
            if name is not None:
                self.by_scope[sid][name] = bid
        # Private-name spelling can be unmangled in the AST/interface.
        for sid, mapping in self.by_scope.items():
            parent: Optional[int] = sid
            while parent is not None and table.scopes[parent].kind != "class":
                parent = table.scopes[parent].parent
            if parent is not None:
                cname = table.scopes[parent].name.lstrip("_")
                if cname:
                    for name, bid in list(mapping.items()):
                        if name.startswith("__") and not name.endswith("__") and "." not in name:
                            mapping["_" + cname + name] = bid
        self.runtime = RuntimeTypes(self.code_map, self.functions, self.class_ids,
                                    self.class_names, depth, elements, nodes)

    def _record(self, category: str, identity: int, line: int, value: Any) -> None:
        if category == "binding":
            self._register_class(identity, value)
        observed = self.runtime.of(value)
        key = (category, identity, _key(observed))
        if key not in self.observations:
            self.observations[key] = {"category": category, "id": identity, "line": line, "type": observed}

    def _register_class(self, identity: int, value: Any) -> None:
        # A class binding can later be rebound to another class (even int).
        # Do not mislabel the replacement with the original declaration id.
        if self.table.bindings[identity].kind == "class" and _is_class(value):
            if _type_attr(value, "__module__") == "__main__" and _type_attr(value, "__name__") == self.class_names.get(identity):
                self.class_ids[id(value)] = identity

    def _snapshot(self, frame: pytypes.FrameType, scope: Optional[int]) -> None:
        # Always sample file globals, even if a particular local scope is ambiguous.
        snapshots: List[Tuple[Dict[str, Any], Mapping[str, int], bool]] = [
            (dict(frame.f_globals), self.by_scope[self.module_scope], False)]
        if scope is not None and scope != self.module_scope:
            snapshots.append((dict(frame.f_locals), self.by_scope[scope], True))
        for values, mapping, is_local in snapshots:
            skipped: Set[str] = set()
            if is_local and scope is not None:
                for start, end, names in self.code_map.inline.get(scope, []):
                    if start <= frame.f_lineno <= end:
                        skipped.update(names)
            # Register class objects before instances in the same snapshot.
            for name, value in values.items():
                bid = mapping.get(name)
                if bid is not None:
                    self._register_class(bid, value)
            for name in sorted(values):
                bid = mapping.get(name)
                if bid is None:
                    continue
                if name in skipped:
                    self.inline_skips.add((scope, name))
                    continue
                self._record("binding", bid, frame.f_lineno, values[name])

    def trace(self, frame: pytypes.FrameType, event: str, arg: Any) -> Optional[Callable[..., Any]]:
        if frame.f_code.co_filename != self.filename:
            return None
        try:
            with self.lock:
                scope = self.code_map.scope_for_code.get(frame.f_code)
                if scope is None:
                    self.skipped_scopes.add(frame.f_code.co_name + ":" + str(frame.f_code.co_firstlineno))
                if event in ("call", "line", "return"):
                    self._snapshot(frame, scope)
                function = self.functions.get(scope)
                if event == "call" and function is not None and self.code_map.initial_call(frame):
                    values = frame.f_locals
                    mapping = self.by_scope[scope]
                    param_ids = {p["binding"] for p in function["params"]}
                    for name, value in values.items():
                        bid = mapping.get(name)
                        if bid in param_ids:
                            self._record("parameter", bid, frame.f_lineno, value)
                if event == "return" and function is not None and self.code_map.actual_return(frame):
                    self._record("return", scope, frame.f_lineno, arg)
        except BaseException as exc:
            # A trace exception disables tracing. Keep tracing and report the
            # oracle error instead of mislabelling a partially observed run ok.
            if len(self.trace_errors) < 10:
                self.trace_errors.append(type(exc).__name__ + ": " + str(exc))
        return self.trace

    def report(self) -> Dict[str, Any]:
        return {"observations": sorted(self.observations.values(), key=lambda x: (x["category"], x["id"], x["line"], _key(x["type"]))),
                "skipped_scopes": sorted(self.skipped_scopes | self.code_map.ambiguous),
                "inline_skips": [[scope, name] for scope, name in sorted(self.inline_skips)],
                "inline_scopes": sorted(self.code_map.inline_scopes),
                "cutoffs": dict(sorted(self.runtime.cutoffs.items())),
                "trace_errors": self.trace_errors[:10]}


def _worker(filename: str, report_path: str, depth: int, elements: int, nodes: int,
            api_path: Optional[str] = None) -> int:
    result: Dict[str, Any] = {"error": None}
    observer: Optional[Observer] = None
    previous_trace = sys.gettrace()
    previous_thread_trace = threading.gettrace() if hasattr(threading, "gettrace") else None
    previous_hook = threading.excepthook
    previous_unraisable = sys.unraisablehook
    thread_errors: List[str] = []
    exit_errors: List[str] = []

    def thread_hook(args: Any) -> None:
        thread_errors.append("".join(traceback.format_exception(args.exc_type, args.exc_value, args.exc_traceback))[-12000:])

    def unraisable_hook(args: Any) -> None:
        exit_errors.append("".join(traceback.format_exception(args.exc_type, args.exc_value, args.exc_traceback))[-12000:])

    def finalize() -> None:
        # Registered before program execution, hence runs after its callbacks.
        # Keep tracing until here so returns and writes in atexit are observed.
        if observer is not None and sys.gettrace() != observer.trace:
            observer.trace_errors.append("program replaced or disabled sys.settrace")
        sys.settrace(previous_trace)
        threading.settrace(previous_thread_trace)
        threading.excepthook = previous_hook
        sys.unraisablehook = previous_unraisable
        if result["error"] is None and (thread_errors or exit_errors):
            result["error"] = "exception in program thread or exit callback: " + (thread_errors + exit_errors)[0]
        if observer is not None:
            with observer.lock:
                result.update(observer.report())
            if observer.trace_errors and result["error"] is None:
                result["error"] = "oracle trace error: " + observer.trace_errors[0]
        try:
            with open(report_path, "w", encoding="utf-8") as stream:
                json.dump(result, stream, ensure_ascii=True, sort_keys=True)
        except BaseException:
            # The parent treats a missing/partial report as an oracle error.
            pass

    atexit.register(finalize)
    try:
        with tokenize.open(filename) as stream:
            source = stream.read()
        tree = ast.parse(source, filename=filename)
        table = symbols.analyze(tree)
        api: Optional[List[Dict[str, Any]]] = None
        if api_path is not None:
            with open(api_path, "r", encoding="utf-8") as stream:
                decoded = json.load(stream)
            if not isinstance(decoded, list) or not all(isinstance(item, dict) for item in decoded):
                raise ValueError("--api manifest must be a JSON list of objects")
            api = decoded
        facts = infer.run(tree, table, api=api).to_json()
        code = compile(source, filename, "exec", dont_inherit=True)
        observer = Observer(filename, tree, table, facts, code, depth, elements, nodes)
        result["facts"] = facts
        result["binding_names"] = {str(b.id): b.name for b in table.bindings}
        result["function_names"] = {str(f["scope"]): table.scopes[f["scope"]].name for f in facts["functions"]}
        sys.argv = [filename]
        sys.path[0] = os.path.dirname(filename)
        # Avoid preloading these ordinary module names into the program's import
        # namespace. References held here keep the analysis modules available.
        sys.modules.pop("infer", None)
        sys.modules.pop("symbols", None)
        namespace: Dict[str, Any] = {"__name__": "__main__", "__file__": filename,
                                     "__package__": None, "__spec__": None, "__cached__": None,
                                     "__builtins__": __builtins__}
        initial_threads = set(threading.enumerate())
        threading.excepthook = thread_hook
        sys.unraisablehook = unraisable_hook
        threading.settrace(observer.trace)
        sys.settrace(observer.trace)
        try:
            exec(code, namespace, namespace)
        except SystemExit as exc:
            if exc.code not in (None, 0):
                raise
        finally:
            # Match the interpreter's normal wait for non-daemon threads. The
            # parent timeout still bounds this wait and kills the child group.
            for thread in threading.enumerate():
                if thread not in initial_threads and not thread.daemon:
                    thread.join()
        if sys.gettrace() != observer.trace:
            observer.trace_errors.append("program replaced or disabled sys.settrace")
    except BaseException:
        result["error"] = "".join(traceback.format_exception(*sys.exc_info()))[-12000:]
    return 0


def _run_child(filename: str, timeout: float, depth: int, elements: int, nodes: int,
               api_path: Optional[str] = None) -> Dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="py2v-infer-oracle-") as directory:
        report_path = os.path.join(directory, "report.json")
        args = [sys.executable, os.path.abspath(__file__), "--_worker", filename, report_path,
                "--depth", str(depth), "--elements", str(elements), "--nodes", str(nodes)]
        if api_path is not None:
            args.extend(["--api", os.path.abspath(api_path)])
        with subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, start_new_session=(os.name == "posix")) as child:
            def terminate() -> None:
                if os.name == "posix":
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                else:
                    child.kill()
                child.wait()

            try:
                child.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                terminate()
                return {"error": "program timeout after " + format(timeout, "g") + " seconds"}
            except BaseException:
                terminate()
                raise
            if child.returncode != 0:
                return {"error": "child process exited with status " + str(child.returncode)}
        try:
            with open(report_path, encoding="utf-8") as stream:
                return json.load(stream)
        except (OSError, ValueError) as exc:
            return {"error": "oracle report unavailable: " + str(exc)}


# Bitwise process status: 1 = inferred contradiction, 2 = assumed mismatch,
# 4 = a failed/unevaluable program or oracle instrumentation failure.
INFERRED_VIOLATION = 1
ASSUMED_VIOLATION = 2
PROGRAM_ERROR = 4


def _show(filename: str, data: Dict[str, Any], missed: bool) -> int:
    if "facts" not in data:
        print(filename + ": error " + str(data.get("error", "missing facts")).replace("\n", " "))
        return PROGRAM_ERROR
    facts = data["facts"]
    table = facts["types"]
    bindings = {b["id"]: b for b in facts["bindings"]}
    functions = {f["scope"]: f for f in facts["functions"]}
    parameters = {p["binding"]: p for f in facts["functions"] for p in f["params"]}
    counts: Counter[str] = Counter()
    violations: List[Tuple[int, str, str, int, str, str, str]] = []
    observed_bindings: Dict[int, Type] = {}
    lines: Dict[int, int] = {}
    for observation in data.get("observations", []):
        category, identity = observation["category"], observation["id"]
        observed, line = observation["type"], observation.get("line") or 0
        if category == "return":
            item = functions[identity]
            expected_ids = (item["ret_inferred"], item["ret_assumed"])
            name = data["function_names"][str(identity)]
        elif category == "parameter":
            item = parameters[identity]
            expected_ids = (item["inferred"], item["assumed"])
            name = data["binding_names"][str(identity)]
        else:
            item = bindings[identity]
            expected_ids = (item["inferred"], item["assumed"])
            name = data["binding_names"][str(identity)]
            observed_bindings[identity] = _join(observed_bindings.get(identity, _NEVER), observed)
            lines[identity] = min(lines.get(identity, line), line)
        counts[category] += 1
        for layer, expected in zip(("inferred", "assumed"), expected_ids):
            if not admits(table, expected, observed):
                violations.append((line, layer, category, identity, name,
                                   infer.render_type(table, expected), render_observed(observed)))
    violation_counts = Counter(v[1] for v in violations)
    for line, layer, category, _, name, expected_text, observed_text in sorted(violations):
        print("{}:{} {} {} {} {} observed {}".format(
            filename, line, category, name, layer, expected_text, observed_text))
    if missed:
        items: List[Tuple[str, int, str, str, str, int]] = []
        reasons: Counter[str] = Counter()
        for identity, observed in observed_bindings.items():
            expected = bindings[identity]["inferred"]
            if table[expected]["k"] not in ("unknown", "dynamic") or not _concrete(observed):
                continue
            reason = table[expected]["why"].split(":", 1)[0]
            reasons[reason] += 1
            items.append((reason, identity, data["binding_names"][str(identity)],
                          infer.render_type(table, expected), render_observed(observed), lines[identity]))
        for reason, _, name, expected_text, observed_text, line in sorted(
                items, key=lambda x: (-reasons[x[0]], x[0], x[5], x[1])):
            print("{}:{} missed binding {} inferred {} observed {} [reason: {}]".format(
                filename, line, name, expected_text, observed_text, reason))
    error = data.get("error")
    if error:
        print(filename + ": error " + str(error).replace("\n", " "))
    else:
        count_i, count_a = violation_counts["inferred"], violation_counts["assumed"]
        status = "ok" if not count_i and not count_a else "violations {} assumed violations {}".format(count_i, count_a)
        detail = "{} binding types, {} argument types, {} return types".format(
            counts["binding"], counts["parameter"], counts["return"])
        print(filename + ": " + status + " (" + detail + ")")
    if data.get("skipped_scopes"):
        print(filename + ": coverage skipped scopes " + ", ".join(data["skipped_scopes"]), file=sys.stderr)
    if data.get("inline_skips"):
        print(filename + ": coverage skipped inlined-comprehension locals " + ", ".join(
            str(s) + ":" + n for s, n in data["inline_skips"]), file=sys.stderr)
    elif data.get("inline_scopes"):
        print(filename + ": coverage inlined-comprehension scopes have no trace frame: " + ", ".join(
            map(str, data["inline_scopes"])), file=sys.stderr)
    if data.get("cutoffs"):
        print(filename + ": coverage inspection cutoffs " + ", ".join(
            k + "=" + str(v) for k, v in sorted(data["cutoffs"].items())), file=sys.stderr)
    return ((INFERRED_VIOLATION if violation_counts["inferred"] else 0)
            | (ASSUMED_VIOLATION if violation_counts["assumed"] else 0)
            | (PROGRAM_ERROR if error else 0))


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="*", help="explicitly trusted programs to execute")
    parser.add_argument("--timeout", type=float, default=10.0, help="seconds per program, including inference (default: 10)")
    parser.add_argument("--missed", action="store_true", help="show observed concrete types behind unknown/dynamic bindings")
    parser.add_argument("--api", metavar="MANIFEST.json", help="use passive library signatures; represented storage types are not checked")
    parser.add_argument("--depth", type=int, default=MAX_DEPTH, help="runtime container inspection depth (default: 4)")
    parser.add_argument("--elements", type=int, default=MAX_ELEMENTS, help="elements inspected per container (default: 32)")
    parser.add_argument("--nodes", type=int, default=MAX_NODES, help="recursive object visits per value (default: 256)")
    parser.add_argument("--_worker", nargs=2, metavar=("FILE", "REPORT"), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    if args.timeout <= 0 or args.depth < 1 or args.elements < 1 or args.nodes < 1:
        parser.error("timeout, depth, elements, and nodes must be positive")
    if args._worker:
        return _worker(args._worker[0], args._worker[1], args.depth, args.elements, args.nodes, args.api)
    if not args.files:
        parser.error("supply at least one program")
    status = 0
    for path in args.files:
        filename = os.path.realpath(os.path.abspath(path))
        try:
            data = _run_child(filename, args.timeout, args.depth, args.elements, args.nodes, args.api)
            status |= _show(path, data, args.missed)
        except KeyboardInterrupt:
            return 130
        except Exception as exc:
            print(path + ": error " + type(exc).__name__ + ": " + str(exc))
            status |= PROGRAM_ERROR
    return status


if __name__ == "__main__":
    raise SystemExit(main())
