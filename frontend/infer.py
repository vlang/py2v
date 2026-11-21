"""Binding-based, bounded, whole-file value-type inference for py2v.

Only ``symbols.analyze`` and the documented symbols metadata are required.
No source under analysis is executed, imported, evaluated, or compiled here.
Python 3.9+; a newer grammar requires the corresponding Python interpreter.

Contract/limits:
* ``inferred`` contains value evidence only; ``assumed`` uses declarations
  when evidence is incomplete, and ``represented`` uses declarations first.
  Each layer has its own fixed point. ``typing.cast`` is the explicit unsound
  transfer requested by the frontend API. All AST value expressions receive
  _type, _assumed, and _represented.
* Type syntax in annotation positions is excluded from expression statistics.
* External module summaries contain structural types, not foreign pool IDs.
  ``--project`` computes at most three synchronous rounds over source files.
* An optional passive JSON API manifest types imported library functions,
  constructors, methods, properties, and constants; _api tags are emitted
  only for qualified imports or uniquely nominal assumed receivers.
* Parameter evidence is closed-world (this file plus defaults and method
  receivers). ``escapes`` warns that external calls can invalidate it.
* Values are flow-sensitive inside a body; binding/field summaries and mutable
  aliases are flow-insensitive. Mutable aliases through names, fields and
  direct calls are tracked; arbitrary heap/object identity is not.
* Union width 4, structural depth 8, fixed tuple length 32, 64 rounds per phase.
  There are two phases: least evidence, then unresolved-evidence completion.
  At a round limit all inferred cells are widened to dynamic and expressions
  are evaluated again. Thus termination does not depend on recursion shape.
* ``may_raise`` includes reachable raise/assert, calls, indexing, attribute
  access, iteration, and potentially failing operators. It ignores resource
  exhaustion and does not subtract caught exceptions.
"""
from __future__ import annotations

import argparse
import ast
import collections
import importlib.util
import json
from pathlib import Path
import sys
import tokenize
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple

import symbols

TypeId = int
JSON = Dict[str, Any]
Key = Tuple[str, int, str]
Env = Dict[Any, TypeId]  # Binding IDs plus local attribute refinements ("attr", binding_id, name).
MAX_UNION = 4
MAX_DEPTH = 8
MAX_TUPLE = 32
MAX_ROUNDS = 64
DEF_NODES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)
COMP_NODES = (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)


def attr(obj: Any, name: str, default: Any = None) -> Any:
    return obj.get(name, default) if isinstance(obj, dict) else getattr(obj, name, default)


def bid(node: ast.AST) -> Optional[int]:
    return getattr(node, "_binding", None)


def dotted(node: ast.AST) -> str:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        prefix = dotted(node.value)
        return prefix + "." + node.attr if prefix else node.attr
    return type(node).__name__


class TypePool:
    """Interned semantic types. ``never`` is the internal evidence bottom."""

    def __init__(self) -> None:
        self.types: List[JSON] = []
        self._index: Dict[str, int] = {}
        self._depth: List[int] = []
        self.never = self.add("never")
        self.none = self.add("none")
        self.bool = self.add("bool")
        self.int = self.add("int")
        self.float = self.add("float")
        self.str = self.add("str")
        self.bytes = self.add("bytes")

    def add(self, k: str, **fields: Any) -> int:
        if k == "union":
            return self.join_all(fields["members"])
        if k == "tuple" and len(fields["elems"]) > MAX_TUPLE:
            return self.add("tuple_of", elem=self.join_all(fields["elems"]))
        children: List[int] = []
        for name in ("elem", "key", "value", "ret"):
            if name in fields:
                children.append(fields[name])
        for name in ("elems", "args", "params"):
            children.extend(fields.get(name, []))
        depth = 1 + max((self._depth[t] for t in children), default=0)
        if depth > MAX_DEPTH:
            return self.dynamic("type nesting limit")
        item = {"k": k, **fields}
        encoded = json.dumps(item, sort_keys=True, separators=(",", ":"))
        if encoded not in self._index:
            self._index[encoded] = len(self.types)
            self.types.append(item)
            self._depth.append(depth)
        return self._index[encoded]

    def unknown(self, why: str) -> int:
        return self.add("unknown", why=why)

    def dynamic(self, why: str) -> int:
        return self.add("dynamic", why=why)

    def instance(self, name: str, args: Sequence[int] = (), binding: Optional[int] = None) -> int:
        return self.add("instance", class_binding=binding, name=name, args=list(args))

    def kind(self, t: int) -> str:
        return self.types[t]["k"]

    def members(self, t: int) -> List[int]:
        return list(self.types[t]["members"]) if self.kind(t) == "union" else [t]

    def join_all(self, ts: Iterable[int]) -> int:
        out = self.never
        for t in ts:
            out = self.join(out, t)
        return out

    def join(self, a: int, b: int) -> int:
        if a == b or b == self.never:
            return a
        if a == self.never:
            return b
        ka, kb = self.kind(a), self.kind(b)
        for wanted in ("dynamic", "unknown"):
            if ka == wanted:
                return a
            if kb == wanted:
                return b
        if ka == kb:
            x, y = self.types[a], self.types[b]
            if ka in ("list", "set", "tuple_of"):
                return self.add(ka, elem=self.join(x["elem"], y["elem"]))
            if ka == "dict":
                return self.add("dict", key=self.join(x["key"], y["key"]), value=self.join(x["value"], y["value"]))
            if ka == "tuple" and len(x["elems"]) == len(y["elems"]):
                return self.add("tuple", elems=[self.join(p, q) for p, q in zip(x["elems"], y["elems"])])
            if ka == "instance" and (x["name"], x["class_binding"], len(x["args"])) == (y["name"], y["class_binding"], len(y["args"])):
                return self.instance(x["name"], [self.join(p, q) for p, q in zip(x["args"], y["args"])], x["class_binding"])
            if ka == "callable" and x["func_binding"] == y["func_binding"] and len(x["params"]) == len(y["params"]):
                return self.add("callable", params=[self.join(p, q) for p, q in zip(x["params"], y["params"])], ret=self.join(x["ret"], y["ret"]), func_binding=x["func_binding"])
        # Coalesce compatible structural alternatives even inside existing unions.
        members = sorted(set(self.members(a) + self.members(b)))
        if 1 + max(self._depth[t] for t in members) > MAX_DEPTH:
            return self.dynamic("type nesting limit")
        for i, left in enumerate(members):
            for j in range(i + 1, len(members)):
                right = members[j]
                if self.kind(left) == self.kind(right) and self.kind(left) in ("list", "set", "dict", "tuple_of"):
                    merged = self.join(left, right)
                    return self.join_all(members[:i] + members[i + 1:j] + members[j + 1:] + [merged])
        if len(members) > MAX_UNION:
            return self.dynamic("union too wide")
        item = {"k": "union", "members": members}
        encoded = json.dumps(item, sort_keys=True, separators=(",", ":"))
        if encoded not in self._index:
            self._index[encoded] = len(self.types)
            self.types.append(item)
            self._depth.append(1 + max(self._depth[t] for t in members))
        return self._index[encoded]

    def without_none(self, t: int) -> int:
        return self.join_all(x for x in self.members(t) if x != self.none)

    def render(self, t: int) -> str:
        return render_type(self.types, t)


def render_type(types: Sequence[Mapping[str, Any]], t: int) -> str:
    x = types[t]
    k = str(x["k"])
    r = lambda v: render_type(types, v)
    if k in ("unknown", "dynamic"):
        return k + "[" + x["why"] + "]"
    if k in ("list", "set", "tuple_of"):
        return k + "[" + r(x["elem"]) + "]"
    if k == "dict":
        return "dict[" + r(x["key"]) + ", " + r(x["value"]) + "]"
    if k in ("tuple", "union"):
        return k + "[" + ", ".join(r(v) for v in x["elems" if k == "tuple" else "members"]) + "]"
    if k == "instance":
        return x["name"] + ("[" + ", ".join(r(v) for v in x["args"]) + "]" if x["args"] else "")
    if k == "class":
        return "type[" + x["name"] + "]"
    if k == "callable":
        return "Callable[[" + ", ".join(r(v) for v in x["params"]) + "], " + r(x["ret"]) + "]"
    if k in ("module", "typevar"):
        return k + "[" + x["name"] + "]"
    return k


def structural_type(types: Sequence[Mapping[str, Any]], t: int,
                    module_name: str = "", local_classes: Optional[Mapping[int, str]] = None,
                    export: bool = False) -> JSON:
    """Self-contained value, with no indices into a foreign pool.

    Exported local nominal classes become qualified external classes; an
    external class never inherits a foreign integer class_binding id.
    """
    original = dict(types[t])
    for key in ("elem", "key", "value", "ret"):
        if key in original:
            original[key] = structural_type(types, original[key], module_name, local_classes, export)
    for key in ("elems", "args", "params", "members"):
        if key in original:
            original[key] = [structural_type(types, v, module_name, local_classes, export) for v in original[key]]
    if export and original["k"] in ("class", "instance"):
        cb = original.get("class_binding")
        if cb is not None:
            spelling = (local_classes or {}).get(cb, str(original.get("name", "")))
            original["name"] = module_name + "." + spelling if module_name else spelling
            original["class_binding"] = None
    if export and original["k"] == "callable":
        original["func_binding"] = None
    return original


def intern_struct(pool: TypePool, node: Mapping[str, Any]) -> int:
    """Import a self-contained type into the caller's intern table."""
    kind = node.get("k", "unknown")
    if not isinstance(kind, str):
        return pool.unknown("malformed external type")
    fields = {key: value for key, value in node.items() if key != "k"}
    for key in ("elem", "key", "value", "ret"):
        if key in fields:
            fields[key] = intern_struct(pool, fields[key])
    for key in ("elems", "args", "params", "members"):
        if key in fields:
            fields[key] = [intern_struct(pool, v) for v in fields[key]]
    if kind in ("never", "none", "bool", "int", "float", "str", "bytes"):
        return getattr(pool, kind)
    if kind not in ("unknown", "dynamic", "list", "set", "dict", "tuple", "tuple_of",
                    "union", "instance", "class", "callable", "module", "typevar"):
        return pool.unknown("unsupported external semantic type: " + kind)
    if kind in ("unknown", "dynamic"):
        fields["why"] = str(fields.get("why", "external incomplete value"))
    return pool.add(kind, **fields)


# Fallback transfer descriptors, used when no API manifest is supplied.
# Manifest signatures are parsed separately without executing imported code.
METHODS: Dict[str, Dict[str, str]] = {
    "str": {**{n: "str" for n in ("capitalize", "casefold", "center", "expandtabs", "format", "format_map", "join", "ljust", "lower", "lstrip", "removeprefix", "removesuffix", "replace", "rjust", "rstrip", "strip", "swapcase", "title", "translate", "upper", "zfill")},
            **{n: "bool" for n in ("isalnum", "isalpha", "isascii", "isdecimal", "isdigit", "isidentifier", "islower", "isnumeric", "isprintable", "isspace", "istitle", "isupper", "startswith", "endswith")},
            **{n: "int" for n in ("count", "find", "index", "rfind", "rindex")},
            "split": "list_str", "rsplit": "list_str", "splitlines": "list_str", "partition": "triple_str", "rpartition": "triple_str", "encode": "bytes"},
    "bytes": {**{n: "bytes" for n in ("capitalize", "center", "expandtabs", "join", "ljust", "lower", "lstrip", "removeprefix", "removesuffix", "replace", "rjust", "rstrip", "strip", "swapcase", "title", "translate", "upper", "zfill")},
              **{n: "int" for n in ("count", "find", "index", "rfind", "rindex")},
              **{n: "bool" for n in ("isalnum", "isalpha", "isascii", "isdigit", "islower", "isspace", "istitle", "isupper", "startswith", "endswith")},
              "decode": "str", "split": "list_bytes", "rsplit": "list_bytes", "splitlines": "list_bytes", "partition": "triple_bytes", "rpartition": "triple_bytes", "hex": "str"},
    "list": {"append": "none", "extend": "none", "insert": "none", "clear": "none", "remove": "none", "reverse": "none", "sort": "none", "pop": "elem", "copy": "self", "count": "int", "index": "int"},
    "set": {"add": "none", "update": "none", "clear": "none", "discard": "none", "remove": "none", "pop": "elem", "copy": "self", "union": "set_join", "intersection": "set_join", "difference": "self", "symmetric_difference": "set_join", "intersection_update": "none", "difference_update": "none", "symmetric_difference_update": "none", "isdisjoint": "bool", "issubset": "bool", "issuperset": "bool"},
    "dict": {"get": "dict_get", "setdefault": "dict_get", "pop": "dict_pop", "popitem": "dict_item", "copy": "self", "clear": "none", "update": "none", "keys": "dict_keys", "values": "dict_values", "items": "dict_items"},
}
STDLIB: Dict[str, str] = {
    "os.path.join": "path_join", "posixpath.join": "path_join", "ntpath.join": "path_join",
    "os.path.exists": "bool", "posixpath.exists": "bool", "ntpath.exists": "bool",
    "os.environ.get": "environ_get", "json.loads": "json", "json.dumps": "str",
    "time.time": "float", "re.compile": "re_compile", "re.match": "re_match",
    "re.search": "re_match", "re.sub": "re_sub", "re.findall": "re_findall",
    "datetime.datetime.now": "datetime", "pathlib.Path": "path", "sqlite3.connect": "connection",
}
ENUM_BASES = {"enum.Enum", "enum.IntEnum", "enum.StrEnum", "enum.Flag", "enum.IntFlag", "Enum", "IntEnum", "StrEnum", "Flag", "IntFlag"}
RICH_METHODS = {"__eq__", "__ne__", "__lt__", "__le__", "__gt__", "__ge__"}
BUILTIN_COMPARABLE = {"none", "bool", "int", "float", "str", "bytes", "list", "tuple", "tuple_of", "dict", "set"}
BUILTINS = set("len range int float str bool bytes list dict set tuple sorted reversed enumerate zip map filter sum min max abs round any all isinstance print open input repr divmod pow ord chr hex bin iter next getattr setattr hasattr type object complex frozenset".split())


@dataclass
class Function:
    node: ast.AST
    scope: int
    binding: Optional[int]
    name: str
    args: ast.arguments
    params: List[ast.arg]
    defaults: Dict[int, ast.expr]
    owner: Optional[int] = None
    flavor: str = "function"
    escapes: bool = False
    generator: bool = False
    ret_declared: Optional[int] = None
    has_return: bool = False
    raises: Set[str] = field(default_factory=set)


@dataclass
class Flow:
    normal: Optional[Env]
    returns: int = 0
    breaks: Optional[Env] = None
    continues: Optional[Env] = None
    raised: bool = False


@dataclass
class TypeFacts:
    types: List[JSON]
    bindings: List[JSON]
    functions: List[JSON]
    classes: List[JSON]
    stats: JSON

    def to_json(self) -> JSON:
        # Return an independent JSON-compatible value, never AST/dataclass objects.
        return json.loads(json.dumps(self.__dict__, ensure_ascii=True))


class Analyzer:
    def __init__(self, tree: ast.Module, table: symbols.SymbolTable,
                 externals: Optional[Mapping[str, JSON]] = None,
                 module_name: Optional[str] = None, is_package: bool = False,
                 base: Optional["Analyzer"] = None,
                 declared_first: bool = False, api: Optional[Sequence[Mapping[str, Any]]] = None) -> None:
        self.tree, self.table = tree, table
        self.p = TypePool()
        self.externals = externals or {}
        self.module_name = module_name or ""
        self.is_package = is_package
        self.base = base
        self.assume = base is not None
        self.declared_first = declared_first
        self.layer = "represented" if declared_first else "assumed" if base is not None else "inferred"
        self.api: Optional[Dict[str, JSON]] = None if api is None else {
            entry["python"]: dict(entry) for entry in api
            if isinstance(entry, Mapping) and isinstance(entry.get("python"), str)
            and entry.get("kind") in ("function", "constructor", "method", "property", "constant", "class")
        }
        self._api_type_cache: Dict[str, int] = {}
        self._base_cache: Dict[int, int] = {}
        self._base_quality: Dict[int, bool] = {}
        self._external_cache: Dict[str, int] = {}
        self._external_class_cache: Dict[str, JSON] = {}
        self.active_class: Optional[int] = None
        self.enum_classes: Set[int] = set()
        self.declared_fields: Dict[Tuple[int, str], int] = {}
        self.annotation_nodes: Set[ast.AST] = set()
        self.nodes = list(ast.walk(tree))
        self.parent = {c: n for n in self.nodes for c in ast.iter_child_nodes(n)}
        self.cells: Dict[Key, int] = {}
        self.declared: Dict[int, int] = {}
        self.provenance: Dict[int, Set[str]] = collections.defaultdict(set)
        self.aliases: Dict[Key, Set[Key]] = collections.defaultdict(set)
        self.targets: Dict[int, Set[int]] = collections.defaultdict(set)
        self.imports: Dict[int, str] = {}
        self.shadowed_qnames: Set[str] = set()
        self.shadowed_member_bindings: Set[Tuple[int, str]] = set()
        self.typevars: Dict[int, str] = {}
        self.classes: Dict[int, ast.ClassDef] = {}
        self.class_names: Dict[str, int] = {}
        self.functions: Dict[int, Function] = {}
        self.methods: Dict[Tuple[int, str], List[int]] = collections.defaultdict(list)
        self.class_attrs: Dict[Tuple[int, str], int] = {}
        self.current: Optional[Function] = None
        self.changed = False
        self.frozen = False
        self.rounds = 0
        self.limit_hit = False
        self._discover()

    def _base_type(self, t: int) -> int:
        assert self.base is not None
        if t not in self._base_cache:
            self._base_cache[t] = intern_struct(self.p, structural_type(self.base.p.types, t))
        return self._base_cache[t]

    def _known(self, t: int) -> bool:
        if t not in self._base_quality:
            # A nested never (e.g. list[never]) is an unsolved element type,
            # not a proof that the declared list[int] is unnecessary.
            def has_never(value: int) -> bool:
                node = self.p.types[value]
                if node["k"] == "never":
                    return True
                children = [node[key] for key in ("elem", "key", "value", "ret") if key in node]
                for key in ("elems", "args", "params", "members"):
                    children.extend(node.get(key, []))
                return any(has_never(child) for child in children)
            self._base_quality[t] = not has_never(t) and classification(self.p.types, t)[0] == "known"
        return self._base_quality[t]

    def _declaration_for(self, key: Key) -> Optional[int]:
        if key[0] in ("b", "p"):
            return self.declared.get(key[1])
        if key[0] == "r":
            f = self.functions.get(key[1])
            return f.ret_declared if f else None
        if key[0] == "f":
            return self.declared_fields.get((key[1], key[2]))
        return None

    def get(self, key: Key) -> int:
        own = self.cells.get(key, self.p.never)
        if not self.assume:
            return own
        declared = self._declaration_for(key)
        # This layer models the representation selected by the emitter: a
        # declaration outranks even concrete contradictory runtime evidence.
        if self.declared_first and declared is not None:
            if key[0] in ("b", "p"):
                self.provenance[key[1]].add("annotation")
            return declared
        # The declared-first pass must propagate its *own* derived types.
        # Otherwise a concrete evidence-only return replaces the declared
        # signature inside a function value and downstream call expressions.
        if self.declared_first and own != self.p.never and self._known(own):
            return own
        if self.base is not None:
            orig = self.base.cells.get(key, self.base.p.never)
            # A field initialized to None is not stable evidence that a mutable
            # annotated pointer can *only* be None after construction. This is
            # intentionally an assumption, not a change to inferred evidence.
            if (key[0] == "f" and declared is not None and orig == self.base.p.none
                    and self.p.kind(declared) != "none"):
                return declared
            if orig != self.base.p.never and self.base._known(orig):
                return self._base_type(orig)
        if declared is not None:
            if key[0] in ("b", "p"):
                self.provenance[key[1]].add("annotation")
            return declared
        if self._known(own):
            return own
        if own != self.p.never:
            return own
        # An unknown from the evidence pass is not positive evidence in the
        # assumed pass. Keep bottom until its own fixed point introduces a
        # concrete value or a final no-evidence fallback.
        return own

    def put(self, key: Key, t: int, why: str = "") -> None:
        if self.frozen:
            return
        # Never join a declaration or a baseline-unknown fallback into the
        # assumed cell: that would poison concrete expression evidence.
        old = self.cells.get(key, self.p.never) if self.assume else self.get(key)
        new = self.p.join(old, t)
        if old != new:
            self.cells[key] = new
            self.changed = True
        if key[0] == "b" and why:
            self.provenance[key[1]].add(why)

    def link(self, a: Key, b: Key) -> None:
        if a != b and b not in self.aliases[a] and not self.frozen:
            self.aliases[a].add(b)
            self.aliases[b].add(a)
            self.changed = True

    def bind(self, b: Optional[int], t: int, why: str = "") -> None:
        if b is not None:
            self.put(("b", b, ""), t, why)

    def risky(self, reason: str) -> None:
        if self.current is not None:
            self.current.raises.add(reason)

    def import_path(self, node: ast.ImportFrom, name: str) -> str:
        module = node.module or ""
        if node.level:
            package = self.module_name if self.is_package else self.module_name.rpartition(".")[0]
            if package:
                try:
                    module = importlib.util.resolve_name("." * node.level + module, package)
                except ImportError:
                    module = "." * node.level + module
            else:
                module = "." * node.level + module
        return module + "." + name if module else name

    def external_entry(self, qualified: str) -> Optional[JSON]:
        """Resolve a fully qualified exported value, never importing its code."""
        if qualified in self.externals:
            return {"kind": "module", "module": qualified}
        for module in sorted(self.externals, key=lambda x: (-len(x), x)):
            if not qualified.startswith(module + "."):
                continue
            path = qualified[len(module) + 1:].split(".")
            summary = self.externals[module]
            name = path.pop(0)
            entry: Optional[JSON] = None
            if name in summary.get("functions", {}):
                entry = {"kind": "function", "module": module, "name": name,
                         "data": summary["functions"][name]}
            elif name in summary.get("classes", {}):
                entry = {"kind": "class", "module": module, "name": name,
                         "data": summary["classes"][name]}
            elif name in summary.get("variables", {}):
                entry = {"kind": "variable", "module": module, "name": name,
                         "data": summary["variables"][name]}
            if entry is None:
                continue
            while path:
                child = path.pop(0)
                if entry["kind"] == "class":
                    cls = entry["data"]
                    if child in cls.get("methods", {}):
                        entry = {"kind": "function", "module": module,
                                 "name": entry["name"] + "." + child,
                                 "data": cls["methods"][child]}
                    elif child in cls.get("fields", {}):
                        entry = {"kind": "field", "module": module, "name": child,
                                 "data": cls["fields"][child]}
                    else:
                        return None
                elif entry["kind"] == "module":
                    nested = self.external_entry(qualified)
                    return nested
                else:
                    return None
            return entry
        return None

    def external_type(self, qualified: str) -> Optional[int]:
        if qualified in self._external_cache:
            return self._external_cache[qualified]
        entry = self.external_entry(qualified)
        if entry is None:
            return None
        kind = entry["kind"]
        if kind == "module":
            t = self.p.add("module", name=entry["module"])
        elif kind == "class":
            t = self.p.add("class", class_binding=None, name=entry["module"] + "." + entry["name"])
        elif kind == "function":
            f = entry["data"]
            layer = self.layer
            def select(data: Mapping[str, Any], prefix: str = "") -> JSON:
                return data.get(prefix + layer, data.get(prefix + "assumed", data.get(prefix + "inferred",
                            {"k": "unknown", "why": "missing external type: " + qualified})))
            t = self.p.add("callable", func_binding=None,
                params=[intern_struct(self.p, select(prm)) for prm in f.get("params", [])],
                ret=intern_struct(self.p, select(f, "ret_")))
        else:
            data = entry["data"]
            layer = self.layer
            t = intern_struct(self.p, data.get(layer, data.get("assumed", data.get("inferred",
                {"k": "unknown", "why": "missing external type: " + qualified}))))
        self._external_cache[qualified] = t
        return t

    def external_class(self, t: int) -> Optional[JSON]:
        item = self.p.types[t]
        if item["k"] not in ("instance", "class"):
            return None
        name = item.get("name", "")
        if name in self._external_class_cache:
            return self._external_class_cache[name]
        entry = self.external_entry(name)
        if entry is not None and entry["kind"] == "class":
            self._external_class_cache[name] = entry["data"]
            return entry["data"]
        return None

    # Runtime-library manifest: passive signatures, never importing code.
    # Resolve solely through an unrebound import, or a nominal receiver type.
    def api_entry(self, qualified: str) -> Optional[JSON]:
        return self.api.get(qualified) if self.api is not None else None

    def imported_api_name(self, node: ast.AST) -> str:
        """Qualified name only if its root is a non-rebound import binding."""
        parts: List[str] = []
        while isinstance(node, ast.Attribute):
            parts.append(node.attr)
            node = node.value
        if not isinstance(node, ast.Name):
            return ""
        binding = bid(node)
        if binding is None or binding not in self.imports or attr(self.table.bindings[binding], "rebound", False):
            return ""
        base = self.imports[binding]
        qualified = base + ("." + ".".join(reversed(parts)) if parts else "")
        return "" if qualified in self.shadowed_qnames else qualified

    def api_type(self, name: str, entry_name: str) -> int:
        """Parse a manifest type expression using the annotation grammar.

        Reclassify all Any leaves as runtime library values with a stable
        per-entry reason. No evaluation, imports, or introspection occur.
        """
        cache_key = entry_name + "\0" + name
        if cache_key in self._api_type_cache:
            return self._api_type_cache[cache_key]
        try:
            parsed = ast.parse(name, mode="eval").body
            original = self.annotation(parsed)
            def convert(t: int) -> int:
                item = self.p.types[t]
                if item["k"] == "dynamic" and item.get("why") == "annotated Any":
                    return self.p.dynamic("library value: " + entry_name)
                fields = {k: v for k, v in item.items() if k != "k"}
                for key in ("elem", "key", "value", "ret"):
                    if key in fields:
                        fields[key] = convert(fields[key])
                for key in ("elems", "args", "params", "members"):
                    if key in fields:
                        fields[key] = [convert(v) for v in fields[key]]
                return self.p.add(item["k"], **fields)
            resolved = convert(original)
        except (SyntaxError, ValueError, TypeError, RecursionError, KeyError) as exc:
            resolved = self.p.unknown("invalid library type: " + entry_name + ": " + name)
        self._api_type_cache[cache_key] = resolved
        return resolved

    def api_result(self, entry: Mapping[str, Any]) -> int:
        name = str(entry["python"])
        ret = entry.get("returns")
        if not isinstance(ret, str) or not ret.strip():
            if entry["kind"] in ("class", "constructor"):
                ret = name
            else:
                return self.p.unknown("missing library result: " + name)
        return self.api_type(ret, name)

    def api_symbol(self, entry: Mapping[str, Any]) -> int:
        name, kind = str(entry["python"]), str(entry["kind"])
        if kind in ("constructor", "class"):
            return self.p.add("class", class_binding=None, name=name)
        if kind in ("property", "constant"):
            return self.api_result(entry)
        if kind in ("function", "method"):
            params = [self.api_type(spec["type"], name) if isinstance(spec, Mapping) and isinstance(spec.get("type"), str)
                      else self.p.unknown("missing library parameter type: " + name)
                      for spec in entry.get("params", [])]
            return self.p.add("callable", params=params, ret=self.api_result(entry), func_binding=None)
        return self.p.unknown("unsupported library entry kind: " + name)

    def api_for_receiver(self, receiver: int, member: str) -> Optional[JSON]:
        """A single concrete manifest class, optionally unioned with None."""
        alternatives = [v for v in self.p.members(receiver) if v != self.p.none]
        if len(alternatives) != 1:
            return None
        t = self.p.types[alternatives[0]]
        if t["k"] not in ("instance", "class") or t.get("class_binding") is not None:
            return None
        parent = t["name"]
        if self.api_entry(parent) is None and not any(k.startswith(parent + ".") for k in (self.api or {})):
            return None
        return self.api_entry(parent + "." + member)

    def api_for_member(self, node: ast.AST, env: Env) -> Optional[JSON]:
        if self.api is None:
            return None
        if (isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) and
                bid(node.value) is not None and
                (bid(node.value), node.attr) in self.shadowed_member_bindings):
            return None
        direct = self.imported_api_name(node)
        entry = self.api_entry(direct)
        if entry is not None:
            return entry
        if isinstance(node, ast.Attribute):
            return self.api_for_receiver(self.expr(node.value, env), node.attr)
        return None

    def _discover(self) -> None:
        for n in self.nodes:
            if isinstance(n, ast.ClassDef) and bid(n) is not None:
                self.classes[bid(n)] = n  # type: ignore[index]
                self.class_names[n.name] = bid(n)  # type: ignore[assignment]
            if isinstance(n, (ast.Import, ast.ImportFrom)):
                for a in n.names:
                    if bid(a) is not None:
                        name = a.name if isinstance(n, ast.Import) else self.import_path(n, a.name)
                        if isinstance(n, ast.Import) and a.asname is None:
                            name = name.split(".")[0]
                        self.imports[bid(a)] = name  # type: ignore[index]
        # Enum values are nominal objects, including IntEnum and StrEnum.
        # Resolve inherited Enum bases within this file without importing code.
        for _ in range(len(self.classes) + 1):
            previous = len(self.enum_classes)
            for cb, cls in self.classes.items():
                if any(self.qname(base) in ENUM_BASES or dotted(base) in ENUM_BASES
                       or bid(base) in self.enum_classes for base in cls.bases):
                    self.enum_classes.add(cb)
            if len(self.enum_classes) == previous:
                break
        for n in self.nodes:
            if isinstance(n, ast.Attribute) and isinstance(n.ctx, (ast.Store, ast.Del)):
                name = self.qname(n)
                if name:
                    self.shadowed_qnames.add(name)
                if isinstance(n.value, ast.Name) and bid(n.value) is not None:
                    self.shadowed_member_bindings.add((bid(n.value), n.attr))
            elif (isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and
                  n.func.id == "setattr" and bid(n.func) is None and len(n.args) >= 2 and
                  isinstance(n.args[0], ast.Name) and bid(n.args[0]) is not None and
                  isinstance(n.args[1], ast.Constant) and isinstance(n.args[1].value, str)):
                self.shadowed_member_bindings.add((bid(n.args[0]), n.args[1].value))
        for n in self.nodes:
            if isinstance(n, ast.Assign) and isinstance(n.value, ast.Call) and self.qname(n.value.func).split(".")[-1] == "TypeVar":
                for target in n.targets:
                    if isinstance(target, ast.Name) and bid(target) is not None:
                        self.typevars[bid(target)] = target.id  # type: ignore[index]
            if type(n).__name__ in ("TypeVar", "ParamSpec", "TypeVarTuple") and bid(n) is not None:
                self.typevars[bid(n)] = str(getattr(n, "name", "T"))  # type: ignore[index]
        for n in self.nodes:
            if not isinstance(n, DEF_NODES):
                continue
            scope = getattr(n, "_scope_id")
            args = n.args
            params = list(args.posonlyargs) + list(args.args)
            defaults = {bid(a): d for a, d in zip(params[len(params) - len(args.defaults):], args.defaults) if bid(a) is not None}
            if args.vararg:
                params.append(args.vararg)
            params.extend(args.kwonlyargs)
            defaults.update({bid(a): d for a, d in zip(args.kwonlyargs, args.kw_defaults) if bid(a) is not None and d is not None})
            if args.kwarg:
                params.append(args.kwarg)
            par = self.parent.get(n)
            outer_scope = attr(self.table.scopes[scope], "parent")
            while outer_scope is not None and attr(self.table.scopes[outer_scope], "kind") == "type_params":
                outer_scope = attr(self.table.scopes[outer_scope], "parent")
            owner = next((cb for cb, cn in self.classes.items() if getattr(cn, "_scope_id") == outer_scope), None)
            module_level = outer_scope is not None and attr(self.table.scopes[outer_scope], "kind") == "module"
            decorators = list(getattr(n, "decorator_list", []))
            flavor = "method" if owner is not None else "function"
            if any(self.qname(d) == "staticmethod" for d in decorators):
                flavor = "staticmethod"
            elif any(self.qname(d) == "classmethod" for d in decorators):
                flavor = "classmethod"
            elif any(self.qname(d) == "property" for d in decorators):
                flavor = "property"
            name = getattr(n, "name", "<lambda>")
            f = Function(n, scope, bid(n), name, args, params, defaults, owner, flavor,
                         bool(decorators) or owner is not None or (module_level and not name.startswith("_")))
            local_nodes = list(self.own_nodes(n))
            f.generator = any(isinstance(c, (ast.Yield, ast.YieldFrom)) for c in local_nodes)
            f.has_return = isinstance(n, ast.Lambda) or any(isinstance(c, ast.Return) for c in local_nodes)
            self.functions[scope] = f
            if f.binding is not None:
                self.targets[f.binding].add(scope)
            if owner is not None:
                self.methods[owner, name].append(scope)
            for a in params:
                if a.annotation is not None and bid(a) is not None:
                    self.declare(bid(a), a.annotation)
            if getattr(n, "returns", None) is not None:
                f.ret_declared = self.annotation(n.returns)
                self.annotation_nodes.update(ast.walk(n.returns))
        for b in self.table.bindings:
            scope = self.table.scopes[attr(b, "scope")]
            if attr(scope, "kind") == "class":
                for cb, n in self.classes.items():
                    if getattr(n, "_scope_id") == attr(scope, "id"):
                        self.class_attrs[cb, attr(b, "name")] = attr(b, "id")
        for n in self.nodes:
            if isinstance(n, ast.AnnAssign) and isinstance(n.target, ast.Name) and bid(n.target) is not None:
                self.declare(bid(n.target), n.annotation)
            if isinstance(n, ast.AnnAssign) and isinstance(n.target, ast.Attribute):
                ancestor = self.parent.get(n)
                while ancestor is not None and not isinstance(ancestor, DEF_NODES):
                    ancestor = self.parent.get(ancestor)
                f = self.functions.get(getattr(ancestor, "_scope_id", None)) if ancestor is not None else None
                if f is not None and f.owner is not None and f.params and isinstance(n.target.value, ast.Name):
                    if n.target.value.id == f.params[0].arg and f.flavor != "staticmethod":
                        key = (f.owner, n.target.attr)
                        t = self.annotation(n.annotation)
                        self.declared_fields[key] = self.p.join(self.declared_fields.get(key, self.p.never), t)
                        self.annotation_nodes.update(ast.walk(n.annotation))
            if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load) and bid(n) in self.targets:
                par = self.parent.get(n)
                if not (isinstance(par, ast.Call) and par.func is n):
                    for s in self.targets[bid(n)]:
                        self.functions[s].escapes = True

    def own_nodes(self, n: ast.AST) -> Iterable[ast.AST]:
        def walk(child: ast.AST) -> Iterable[ast.AST]:
            if isinstance(child, DEF_NODES):
                headers = list(child.args.defaults) + [d for d in child.args.kw_defaults if d is not None] + list(getattr(child, "decorator_list", []))
                for header in headers:
                    yield from walk(header)
                return
            if isinstance(child, ast.ClassDef):
                for header in list(child.bases) + [k.value for k in child.keywords] + list(child.decorator_list):
                    yield from walk(header)
                return
            yield child
            for c in ast.iter_child_nodes(child):
                yield from walk(c)
        body = [n.body] if isinstance(n, ast.Lambda) else n.body
        for child in body:
            yield from walk(child)

    def declare(self, b: int, n: ast.expr) -> None:
        t = self.annotation(n)
        self.declared[b] = self.p.join(self.declared.get(b, self.p.never), t)
        self.provenance[b].add("annotation")
        self.annotation_nodes.update(ast.walk(n))

    def qname(self, n: ast.AST) -> str:
        if isinstance(n, ast.Name):
            b = bid(n)
            if b in self.imports and not attr(self.table.bindings[b], "rebound", False):
                return self.imports[b]
            if b is None:
                if any(attr(s, "has_star_import", False) for s in self.table.scopes):
                    return ""
                return "" if "builtins." + n.id in self.shadowed_qnames else n.id
            if b in self.typevars:
                return self.typevars[b]
            return ""
        if isinstance(n, ast.Attribute):
            base = self.qname(n.value)
            qualified = base + "." + n.attr if base else ""
            return "" if qualified in self.shadowed_qnames else qualified
        return ""

    def annotation(self, n: ast.AST, depth: int = 0) -> int:
        p = self.p
        if depth > MAX_DEPTH:
            return p.unknown("annotation nesting limit")
        rec = lambda v: self.annotation(v, depth + 1)
        if isinstance(n, ast.Constant):
            if n.value is None:
                return p.none
            if isinstance(n.value, str):
                try:
                    return rec(ast.parse(n.value, mode="eval").body)
                except (SyntaxError, ValueError, RecursionError):
                    return p.unknown("invalid string annotation: " + n.value)
        if isinstance(n, ast.BinOp) and isinstance(n.op, ast.BitOr):
            return p.join(rec(n.left), rec(n.right))
        if isinstance(n, (ast.Name, ast.Attribute)):
            name = self.qname(n) or dotted(n)
            short = name.rsplit(".", 1)[-1]
            if bid(n) in self.classes:
                cb = bid(n)
                return p.instance(self.classes[cb].name, binding=cb)
            if short in ("Any",):
                return p.dynamic("annotated Any")
            if short in ("None", "NoneType"):
                return p.none
            if short in ("Never", "NoReturn"):
                return p.never
            if short in ("bool", "int", "float", "str", "bytes"):
                return getattr(p, short)
            if short == "u64":
                return p.int
            if short in ("list", "List", "set", "Set", "dict", "Dict", "tuple", "Tuple"):
                u = p.unknown("unparameterized annotation: " + short)
                k = short.lower()
                return p.add("dict", key=u, value=u) if k == "dict" else p.add("tuple_of" if k == "tuple" else k, elem=u)
            if bid(n) in self.typevars or short in self.typevars.values():
                return p.add("typevar", name=short)
            matches = [cb for cb, cn in self.classes.items() if cn.name == short] if isinstance(n, ast.Name) else []
            if len(matches) > 1:
                return p.unknown("ambiguous forward class annotation: " + short)
            cb = matches[0] if matches else None
            if cb is not None:
                return p.instance(self.classes[cb].name, binding=cb)
            return p.instance(name)
        if isinstance(n, ast.Subscript):
            name = (self.qname(n.value) or dotted(n.value)).rsplit(".", 1)[-1]
            sl = n.slice
            parts = list(sl.elts) if isinstance(sl, ast.Tuple) else [sl]
            if name in ("Final", "ClassVar", "Annotated", "Required", "NotRequired"):
                return rec(parts[0])
            if name == "Literal":
                return p.join_all(self.literal_type(x) for x in parts)
            if name == "Optional":
                return p.join(rec(parts[0]), p.none)
            if name == "Union":
                return p.join_all(rec(x) for x in parts)
            if name in ("List", "list", "Set", "set", "FrozenSet", "frozenset"):
                return p.add("list" if name in ("List", "list") else "set", elem=rec(parts[0]))
            if name in ("Dict", "dict", "Mapping", "MutableMapping"):
                return p.add("dict", key=rec(parts[0]), value=rec(parts[1])) if len(parts) == 2 else p.unknown("invalid mapping annotation")
            if name in ("Tuple", "tuple"):
                if len(parts) == 2 and isinstance(parts[1], ast.Constant) and parts[1].value is Ellipsis:
                    return p.add("tuple_of", elem=rec(parts[0]))
                return p.add("tuple", elems=[rec(x) for x in parts])
            if name in ("Iterable", "Iterator", "Sequence", "MutableSequence", "Generator", "Coroutine", "Awaitable"):
                return p.instance("collections.abc." + name, [rec(x) for x in parts])
            if name == "Callable" and len(parts) == 2:
                params = [rec(x) for x in parts[0].elts] if isinstance(parts[0], (ast.List, ast.Tuple)) else [p.unknown("variadic callable annotation")]
                return p.add("callable", params=params, ret=rec(parts[1]), func_binding=None)
            base = rec(n.value)
            if p.kind(base) == "instance":
                info = p.types[base]
                return p.instance(info["name"], [rec(x) for x in parts], info["class_binding"])
        return p.unknown("unsupported annotation: " + ast.dump(n, include_attributes=False))

    def literal_type(self, n: ast.AST) -> int:
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.UAdd, ast.USub)):
            return self.literal_type(n.operand)
        if not isinstance(n, ast.Constant):
            return self.p.unknown("nonliteral Literal argument: " + dotted(n))
        value = n.value
        kinds = {type(None): "none", bool: "bool", int: "int", float: "float", str: "str", bytes: "bytes"}
        if type(value) in kinds:
            return getattr(self.p, kinds[type(value)])
        return self.p.instance("complex" if isinstance(value, complex) else "ellipsis")

    def element(self, t: int) -> int:
        p, x = self.p, self.p.types[t]
        k = x["k"]
        if k in ("never", "unknown", "dynamic"):
            return t
        if k == "union":
            return p.join_all(self.element(v) for v in x["members"])
        if k in ("list", "set", "tuple_of"):
            return x["elem"]
        if k == "dict":
            return x["key"]
        if k == "tuple":
            return p.join_all(x["elems"])
        if k in ("str", "bytes"):
            return p.str if k == "str" else p.int
        if k == "instance":
            if x["name"] == "range":
                return p.int
            if x["name"].startswith("collections.abc.") and x["args"]:
                return x["args"][0]
            if x["name"] in ("io.TextIOBase", "io.TextIOWrapper"):
                return p.str
            if x["name"] in ("io.BufferedIOBase", "io.BufferedReader"):
                return p.bytes
        return p.unknown("iteration element of unsupported type: " + p.render(t))

    def iterator(self, t: int) -> int:
        return self.p.instance("collections.abc.Iterator", [t])

    @staticmethod
    def attr_key(n: ast.AST) -> Optional[Tuple[str, int, str]]:
        if isinstance(n, ast.Attribute) and isinstance(n.value, ast.Name) and bid(n.value) is not None:
            return ("attr", bid(n.value), n.attr)  # type: ignore[return-value]
        return None

    def env_join(self, a: Optional[Env], b: Optional[Env]) -> Optional[Env]:
        if a is None:
            return None if b is None else dict(b)
        if b is None:
            return dict(a)
        # Attribute refinements exist only if both paths prove them. They must
        # not survive a merge with an unrefined branch.
        out: Env = {}
        for i in sorted(set(a) | set(b), key=lambda v: (isinstance(v, tuple), str(v))):
            if isinstance(i, tuple):
                if i in a and i in b:
                    out[i] = self.p.join(a[i], b[i])
            else:
                fallback = self.get(("b", i, ""))
                out[i] = self.p.join(a.get(i, fallback), b.get(i, fallback))
        return out

    def keys(self, n: ast.AST, env: Env) -> List[Key]:
        if isinstance(n, ast.Name) and bid(n) is not None:
            return [("b", bid(n), "")]  # type: ignore[list-item]
        if isinstance(n, ast.Call):
            targets = self.function_targets(n.func)
            if isinstance(n.func, ast.Attribute):
                receiver = self.expr(n.func.value, env)
                for v in self.p.members(receiver):
                    x = self.p.types[v]
                    if x["k"] in ("instance", "class") and x["class_binding"] in self.classes:
                        targets += self.methods.get((x["class_binding"], n.func.attr), [])
            return [("r", scope, "") for scope in sorted(set(targets)) if not self.functions[scope].generator and not isinstance(self.functions[scope].node, ast.AsyncFunctionDef)]
        if isinstance(n, ast.Attribute):
            t = self.expr(n.value, env)
            return [("f", self.p.types[v]["class_binding"], n.attr) for v in self.p.members(t)
                    if self.p.kind(v) in ("instance", "class") and self.p.types[v]["class_binding"] in self.classes]
        return []

    def mutate(self, n: ast.AST, shape: int, env: Env, why: str = "container-write") -> None:
        pending = self.keys(n, env)
        seen: Set[Key] = set()
        while pending:
            key = pending.pop()
            if key in seen:
                continue
            seen.add(key)
            self.put(key, shape, why)
            if key[0] == "b" and key[1] in env:
                env[key[1]] = self.p.join(env[key[1]], shape)
            pending.extend(sorted(self.aliases[key]))
        if isinstance(n, ast.Subscript):
            base = self.expr(n.value, env)
            shapes: List[int] = []
            for t in self.p.members(base):
                x = self.p.types[t]
                if x["k"] in ("list", "tuple_of"):
                    shapes.append(self.p.add(x["k"], elem=shape))
                elif x["k"] == "dict":
                    shapes.append(self.p.add("dict", key=x["key"], value=shape))
                elif x["k"] == "tuple":
                    es = list(x["elems"])
                    i = self.const_int(n.slice)
                    if i is not None and -len(es) <= i < len(es):
                        es[i] = self.p.join(es[i], shape)
                    else:
                        es = [self.p.join(v, shape) for v in es]
                    shapes.append(self.p.add("tuple", elems=es))
            if shapes:
                self.mutate(n.value, self.p.join_all(shapes), env, why)

    @staticmethod
    def const_int(n: ast.AST) -> Optional[int]:
        if isinstance(n, ast.Constant) and type(n.value) is int:
            return n.value
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.UAdd, ast.USub)):
            value = Analyzer.const_int(n.operand)
            return None if value is None else (-value if isinstance(n.op, ast.USub) else value)
        return None

    def read_name(self, n: ast.Name, env: Env) -> int:
        p, b = self.p, bid(n)
        if b is None:
            name = self.qname(n)
            if name in ("int", "float", "str", "bool", "bytes", "list", "dict", "set", "tuple", "type", "object", "complex", "frozenset"):
                return p.add("class", class_binding=None, name=name)
            if name in BUILTINS:
                return p.add("callable", params=[], ret=p.unknown("builtin signature depends on arguments: " + name), func_binding=None)
            return p.unknown("unresolved name: " + n.id)
        manifest = self.api_entry(self.imported_api_name(n)) if isinstance(n.ctx, ast.Load) else None
        if manifest is not None:
            return self.api_symbol(manifest)
        t = env.get(b, self.get(("b", b, "")))
        # Container summaries include mutations later in this scope/captured scopes.
        if p.kind(t) in ("list", "set", "dict", "tuple", "tuple_of"):
            for v in p.members(self.get(("b", b, ""))):
                if p.kind(v) == p.kind(t):
                    t = p.join(t, v)
        return t

    def expr(self, n: Optional[ast.AST], env: Env) -> int:
        if n is None:
            return self.p.none
        t = self._expr(n, env)
        known = getattr(n, "_api_returns", "")
        if known in ("str", "bool", "int", "float", "bytes"):
            # A call into the runtime library whose manifest entry states a plain type
            t = getattr(self.p, known)
        n._type = self.p.join(getattr(n, "_type", self.p.never), t)  # type: ignore[attr-defined]
        return t

    def _expr(self, n: ast.AST, env: Env) -> int:
        p = self.p
        if isinstance(n, ast.Constant):
            return self.literal_type(n)
        if isinstance(n, ast.Name):
            return self.read_name(n, env)
        if isinstance(n, ast.NamedExpr):
            t = self.expr(n.value, env)
            self.assign(n.target, t, env, "named-expression", n.value)
            return t
        if isinstance(n, (ast.List, ast.Set, ast.Tuple)):
            values: List[int] = []
            variable_tuple = False
            for child in n.elts:
                if isinstance(child, ast.Starred):
                    v = self.expr(child.value, env)
                    self.expr(child, env)
                    if p.kind(v) == "tuple":
                        values.extend(p.types[v]["elems"])
                    else:
                        variable_tuple = True
                        values.append(self.element(v))
                else:
                    values.append(self.expr(child, env))
            if isinstance(n, ast.Tuple):
                return p.add("tuple_of", elem=p.join_all(values)) if variable_tuple else p.add("tuple", elems=values)
            return p.add("list" if isinstance(n, ast.List) else "set", elem=p.join_all(values))
        if isinstance(n, ast.Dict):
            keys: List[int] = []
            values = []
            for key, value in zip(n.keys, n.values):
                if key is None:
                    t = self.expr(value, env)
                    if p.kind(t) == "dict":
                        keys.append(p.types[t]["key"])
                        values.append(p.types[t]["value"])
                    else:
                        keys.append(p.unknown("mapping unpack key: " + dotted(value)))
                        values.append(p.unknown("mapping unpack value: " + dotted(value)))
                else:
                    keys.append(self.expr(key, env))
                    values.append(self.expr(value, env))
            return p.add("dict", key=p.join_all(keys), value=p.join_all(values))
        if isinstance(n, ast.BinOp):
            a, b = self.expr(n.left, env), self.expr(n.right, env)
            return self.binary(n.op, a, b, n.right)
        if isinstance(n, ast.UnaryOp):
            t = self.expr(n.operand, env)
            self.risky("unary operator")
            if isinstance(n.op, ast.Not):
                return p.bool
            if p.kind(t) in ("never", "unknown", "dynamic"):
                return t
            self.risky("unary operator")
            return p.join_all(p.int if p.kind(v) in ("bool", "int") else p.float if p.kind(v) == "float" and not isinstance(n.op, ast.Invert) else p.unknown("overloaded unary operator: " + p.render(v)) for v in p.members(t))
        if isinstance(n, ast.BoolOp):
            active: Optional[Env] = dict(env)
            result = p.never
            exits: Optional[Env] = None
            for i, child in enumerate(n.values):
                if active is None:
                    break
                t = self.expr(child, active)
                if i == len(n.values) - 1:
                    result = p.join(result, t)
                    exits = self.env_join(exits, active)
                    break
                yes, no = self.narrow(child, active)
                short = yes if isinstance(n.op, ast.Or) else no
                if short is not None:
                    returned = p.without_none(t) if isinstance(n.op, ast.Or) else t
                    result = p.join(result, returned)
                    exits = self.env_join(exits, short)
                active = no if isinstance(n.op, ast.Or) else yes
            if exits is not None:
                env.update(exits)
            return result
        if isinstance(n, ast.Compare):
            ts = [self.expr(n.left, env)]
            exits: Optional[Env] = None
            for i, comparator in enumerate(n.comparators):
                if i:
                    exits = self.env_join(exits, env)
                ts.append(self.expr(comparator, env))
            merged = self.env_join(exits, env)
            if merged is not None:
                env.update(merged)
            if all(isinstance(op, (ast.Is, ast.IsNot, ast.In, ast.NotIn)) for op in n.ops):
                if any(isinstance(op, (ast.In, ast.NotIn)) for op in n.ops):
                    self.risky("membership test")
                return p.bool
            self.risky("comparison")
            def bool_comparison(value: int) -> bool:
                for alternative in p.members(value):
                    kind = p.kind(alternative)
                    if kind in BUILTIN_COMPARABLE:
                        continue
                    if kind == "instance":
                        cb = p.types[alternative].get("class_binding")
                        if cb in self.classes and not any((cb, name) in self.methods for name in RICH_METHODS):
                            continue
                    return False
                return True
            if all(bool_comparison(t) for t in ts):
                return p.bool
            return p.unknown("rich comparison may return non-bool")
        if isinstance(n, ast.IfExp):
            self.expr(n.test, env)
            yes, no = self.narrow(n.test, env)
            a = self.expr(n.body, yes) if yes is not None else p.never
            b = self.expr(n.orelse, no) if no is not None else p.never
            merged = self.env_join(yes, no)
            if merged is not None:
                env.update(merged)
            return p.join(a, b)
        if isinstance(n, (ast.JoinedStr, ast.FormattedValue)):
            for c in ast.iter_child_nodes(n):
                self.expr(c, env)
            return p.str
        if type(n).__name__ in ("TemplateStr", "Interpolation"):
            for c in ast.iter_child_nodes(n):
                self.expr(c, env)
            return p.instance("string.templatelib.Template") if type(n).__name__ == "TemplateStr" else p.instance("string.templatelib.Interpolation")
        if isinstance(n, ast.Slice):
            self.expr(n.lower, env)
            self.expr(n.upper, env)
            self.expr(n.step, env)
            return p.instance("slice")
        if isinstance(n, ast.Subscript):
            value = self.expr(n.value, env)
            self.expr(n.slice, env)
            self.risky("subscript")
            return p.join_all(self.subscript(v, n.slice) for v in p.members(value))
        if isinstance(n, ast.Attribute):
            value = self.expr(n.value, env)
            self.risky("attribute access")
            refined = self.attr_key(n)
            if refined is not None and refined in env:
                return env[refined]
            manifest = self.api_for_member(n, env)
            if manifest is not None:
                return self.api_symbol(manifest)
            qn = self.qname(n)
            external = self.external_type(qn) if qn else None
            if external is not None:
                return external
            if self.api is None and qn == "os.environ":
                return p.instance("os._Environ", [p.str, p.str])
            if self.api is None and qn in STDLIB:
                return p.add("callable", params=[], ret=p.unknown("library callable requires arguments: " + qn), func_binding=None)
            par = self.parent.get(n)
            if not (isinstance(par, ast.Call) and par.func is n) and n.attr in ("append", "extend", "insert", "add", "update", "setdefault", "symmetric_difference_update"):
                self.escape_mutable(n.value, value, env, "escaped bound mutator: " + n.attr)
            return p.join_all(self.attribute(v, n.attr) for v in p.members(value))
        if isinstance(n, ast.Call):
            return self.call(n, env)
        if isinstance(n, ast.Lambda):
            self.definition(n, env)
            return self.function_type(self.functions[getattr(n, "_scope_id")])
        if isinstance(n, COMP_NODES):
            local = dict(env)
            for gen in n.generators:
                iterable = self.expr(gen.iter, local)
                self.assign(gen.target, self.element(iterable), local, "for-over:" + p.kind(iterable))
                for test in gen.ifs:
                    self.expr(test, local)
                    yes, _ = self.narrow(test, local)
                    if yes is not None:
                        local = yes
            if isinstance(n, ast.DictComp):
                if n.value is None:  # Python 3.15, PEP 798: {**mapping for ...}
                    source = self.expr(n.key, local)
                    result = self.dict_input(source)
                else:
                    result = p.add("dict", key=self.expr(n.key, local), value=self.expr(n.value, local))
            else:
                if isinstance(n.elt, ast.Starred):  # PEP 798: [*xs for ...]
                    iterable = self.expr(n.elt.value, local)
                    elem = self.element(iterable)
                    n.elt._type = p.join(getattr(n.elt, "_type", p.never), elem)
                else:
                    elem = self.expr(n.elt, local)
                result = p.add("list" if isinstance(n, ast.ListComp) else "set", elem=elem) if not isinstance(n, ast.GeneratorExp) else p.instance("collections.abc.Generator", [elem, p.none, p.none])
            for child in ast.walk(n):
                if isinstance(child, ast.NamedExpr) and bid(child.target) is not None:
                    b = bid(child.target)
                    env[b] = p.join(env.get(b, self.get(("b", b, ""))), local.get(b, self.get(("b", b, ""))))
            return result
        if isinstance(n, ast.Starred):
            return self.element(self.expr(n.value, env))
        if isinstance(n, ast.Yield):
            value = self.expr(n.value, env)
            if self.current:
                self.put(("y", self.current.scope, ""), value)
            return p.unknown("value sent into generator")
        if isinstance(n, ast.YieldFrom):
            value = self.expr(n.value, env)
            if self.current:
                self.put(("y", self.current.scope, ""), self.element(value))
            x = p.types[value]
            return x["args"][2] if x["k"] == "instance" and x["name"] == "collections.abc.Generator" and len(x["args"]) == 3 else p.unknown("yield-from terminal value")
        if isinstance(n, ast.Await):
            value = self.expr(n.value, env)
            return p.join_all(p.types[v]["args"][-1] if p.kind(v) == "instance" and p.types[v]["name"] in ("collections.abc.Coroutine", "collections.abc.Awaitable") and p.types[v]["args"] else p.unknown("awaited value: " + p.render(v)) for v in p.members(value))
        for c in ast.iter_child_nodes(n):
            if isinstance(c, ast.expr):
                self.expr(c, env)
        return p.unknown("unsupported expression: " + type(n).__name__)

    def binary(self, op: ast.operator, a: int, b: int, right: Optional[ast.AST] = None) -> int:
        p = self.p
        if a == p.never or b == p.never:
            return p.never
        self.risky("binary operator")
        if p.kind(a) in ("unknown", "dynamic") or p.kind(b) in ("unknown", "dynamic"):
            return p.join(a, b)
        if p.kind(a) == "union" or p.kind(b) == "union":
            return p.join_all(self.binary(op, x, y, right) for x in p.members(a) for y in p.members(b))
        x, y = p.types[a], p.types[b]
        ka, kb = x["k"], y["k"]
        numeric = {"int", "bool", "float"}
        self.risky("binary operator")
        if ka in numeric and kb in numeric:
            if isinstance(op, ast.Div):
                return p.float
            if isinstance(op, ast.Pow):
                exponent = self.const_int(right) if right is not None else None
                if ka in ("int", "bool") and kb in ("int", "bool"):
                    return p.int if exponent is not None and exponent >= 0 else p.float if exponent is not None else p.join(p.int, p.float)
                return p.join(p.float, p.instance("complex")) if kb == "float" else p.float
            if isinstance(op, (ast.BitAnd, ast.BitOr, ast.BitXor)):
                return p.bool if ka == kb == "bool" else p.int if "float" not in (ka, kb) else p.never
            if isinstance(op, (ast.LShift, ast.RShift)):
                return p.int if "float" not in (ka, kb) else p.never
            if isinstance(op, ast.MatMult):
                return p.never
            return p.float if "float" in (ka, kb) else p.int
        if isinstance(op, ast.Add) and ka == kb:
            if ka in ("str", "bytes"):
                return a
            if ka in ("list", "tuple_of"):
                return p.join(a, b)
            if ka == "tuple":
                return p.add("tuple", elems=x["elems"] + y["elems"])
        if isinstance(op, ast.Mult):
            if kb in ("int", "bool") and ka in ("str", "bytes", "list", "tuple", "tuple_of"):
                if ka == "tuple":
                    count = self.const_int(right) if right is not None else None
                    return p.add("tuple", elems=x["elems"] * max(0, count)) if count is not None and len(x["elems"]) * max(0, count) <= MAX_TUPLE else p.add("tuple_of", elem=self.element(a))
                return a
            if ka in ("int", "bool") and kb in ("str", "bytes", "list", "tuple", "tuple_of"):
                return b if kb != "tuple" else p.add("tuple_of", elem=self.element(b))
        if isinstance(op, ast.Mod) and ka in ("str", "bytes"):
            return a
        if ka == kb == "set" and isinstance(op, (ast.BitOr, ast.BitAnd, ast.BitXor, ast.Sub)):
            return p.join(a, b)
        if ka == kb == "dict" and isinstance(op, ast.BitOr):
            return p.join(a, b)
        return p.unknown("unsupported binary operands: " + ka + " " + type(op).__name__ + " " + kb)

    def subscript(self, t: int, index: ast.AST) -> int:
        p, x = self.p, self.p.types[t]
        k = x["k"]
        if k in ("never", "unknown", "dynamic"):
            return t
        if isinstance(index, ast.Slice):
            if k in ("str", "bytes", "list", "tuple_of"):
                return t
            if k == "tuple":
                vals: List[Optional[int]] = []
                for part in (index.lower, index.upper, index.step):
                    if part is None or (isinstance(part, ast.Constant) and part.value is None):
                        vals.append(None)
                    else:
                        v = self.const_int(part)
                        if v is None:
                            return p.add("tuple_of", elem=self.element(t))
                        vals.append(v)
                if vals[2] == 0:
                    return p.never
                return p.add("tuple", elems=x["elems"][slice(*vals)])
        if k in ("str", "bytes"):
            return p.str if k == "str" else p.int
        if k in ("list", "tuple_of"):
            return x["elem"]
        if k == "dict":
            return x["value"]
        if k == "tuple":
            i = self.const_int(index)
            if i is not None:
                return x["elems"][i] if -len(x["elems"]) <= i < len(x["elems"]) else p.never
            return self.element(t)
        if k == "instance" and x["name"] == "range":
            return t if isinstance(index, ast.Slice) else p.int
        return p.unknown("subscript of unsupported type: " + p.render(t))

    def attribute(self, t: int, name: str) -> int:
        p, x = self.p, self.p.types[t]
        k = x["k"]
        if k in ("never", "unknown", "dynamic"):
            return t
        if k == "union":
            # getattr(None, name) raises; where attribute access returns a
            # value, it came from a non-None member. Preserve user's rule.
            return p.join_all(self.attribute(v, name) for v in x["members"] if v != p.none)
        if k in ("instance", "class") and x["class_binding"] in self.classes:
            cb = x["class_binding"]
            methods = self.methods.get((cb, name), [])
            value = p.join(self.get(("f", cb, name)), self.get(("h", cb, "")))
            if methods:
                return p.join(value, p.join_all(p.unknown("decorated method value: " + self.functions[s].name) if self.unsafe_decorator(self.functions[s]) else self.get(("r", s, "")) if self.functions[s].flavor == "property" else self.function_type(self.functions[s]) for s in methods))
            ab = self.class_attrs.get((cb, name))
            if cb in self.enum_classes and ab is not None and not name.startswith("_"):
                return p.instance(self.classes[cb].name, binding=cb)
            if ab is not None:
                value = p.join(value, self.get(("b", ab, "")))
            return value
        manifest = self.api_for_receiver(t, name)
        if manifest is not None:
            return self.api_symbol(manifest)
        external = self.external_class(t)
        if external is not None:
            fields = external.get("fields", {})
            if name in fields:
                layer = self.layer
                return intern_struct(p, fields[name].get(layer, fields[name].get("assumed", fields[name].get("inferred",
                    {"k": "unknown", "why": "untyped external field: " + name}))))
            methods = external.get("methods", {})
            if name in methods:
                f = methods[name]
                layer = self.layer
                params = f.get("params", [])
                if x["k"] == "instance" and f.get("flavor") not in ("staticmethod", "classmethod"):
                    params = params[1:]
                def select(data: Mapping[str, Any], prefix: str = "") -> JSON:
                    return data.get(prefix + layer, data.get(prefix + "assumed", data.get(prefix + "inferred",
                        {"k": "unknown", "why": "missing external type: " + x["name"] + "." + name})))
                return p.add("callable", func_binding=None,
                    params=[intern_struct(p, select(prm)) for prm in params],
                    ret=intern_struct(p, select(f, "ret_")))
        if k == "module":
            qualified = x["name"] + "." + name
            value = self.external_type(qualified)
            if value is not None:
                return value
            if qualified in ("os.path",):
                return p.add("module", name=qualified)
            return p.unknown("unknown module attribute: " + qualified)
        if k in METHODS and name in METHODS[k]:
            return p.add("callable", params=[], ret=self.method_result(t, name, [], {}), func_binding=None)
        if self.api is None and k == "instance" and x["name"] == "pathlib.Path" and name in ("name", "stem", "suffix"):
            return p.str
        if self.api is None and k == "instance" and x["name"] == "pathlib.Path" and name == "parent":
            return t
        return p.unknown("unknown attribute: " + p.render(t) + "." + name)

    def unsafe_decorator(self, f: Function) -> bool:
        return any(self.qname(d) not in ("staticmethod", "classmethod", "property") for d in getattr(f.node, "decorator_list", []))

    def function_type(self, f: Function) -> int:
        return self.p.add("callable", params=[self.get(("p", bid(a), "")) for a in f.params],
                          ret=self.call_return(f), func_binding=f.binding)

    def call_return(self, f: Function) -> int:
        ret = self.get(("r", f.scope, ""))
        if f.generator and isinstance(f.node, ast.AsyncFunctionDef):
            return self.p.instance("collections.abc.AsyncGenerator", [self.get(("y", f.scope, "")), self.p.unknown("generator send type")])
        if f.generator:
            return self.p.instance("collections.abc.Generator", [self.get(("y", f.scope, "")), self.p.unknown("generator send type"), ret])
        if isinstance(f.node, ast.AsyncFunctionDef):
            return self.p.instance("collections.abc.Coroutine", [ret])
        return ret

    def definition(self, n: ast.AST, env: Env) -> None:
        f = self.functions[getattr(n, "_scope_id")]
        for b, value in f.defaults.items():
            self.put(("p", b, ""), self.expr(value, env))
            for key in self.keys(value, env):
                self.link(("p", b, ""), key)
            self.provenance[b].add("default")
        for d in getattr(n, "decorator_list", []):
            self.expr(d, env)
        t = self.function_type(f)
        if f.flavor in ("classmethod", "staticmethod", "property"):
            t = self.p.instance(f.flavor, [t])
        if any(self.qname(d) not in ("staticmethod", "classmethod", "property") for d in getattr(n, "decorator_list", [])):
            t = self.p.unknown("decorated function value: " + f.name)
        if f.binding is not None:
            self.bind(f.binding, t, "function-definition")
            env[f.binding] = t

    def function_targets(self, n: ast.AST) -> List[int]:
        if isinstance(n, ast.Lambda):
            return [getattr(n, "_scope_id")]
        return sorted(self.targets.get(bid(n), set()))

    def pass_arguments(self, f: Function, args: List[Tuple[int, Optional[ast.AST]]], kws: Dict[str, Tuple[int, Optional[ast.AST]]], star: Optional[int], kwstar: Optional[int], env: Env) -> None:
        self.risky("in-file call with unchecked argument binding: " + f.name)
        pos = list(f.args.posonlyargs) + list(f.args.args)
        assigned: Set[int] = set()
        for i, a in enumerate(pos):
            b = bid(a)
            item: Optional[Tuple[int, Optional[ast.AST]]] = args[i] if i < len(args) else None
            if item is None and a not in f.args.posonlyargs:
                item = kws.get(a.arg)
            if item is None and (star is not None or (kwstar is not None and a not in f.args.posonlyargs)):
                ts = [v for v in (star, kwstar) if v is not None]
                item = (self.p.join_all(ts), None)
            if item is None and b in f.defaults:
                self.provenance[b].add("callsites")
            if item is not None and b is not None:
                self.put(("p", b, ""), item[0])
                self.provenance[b].add("callsites")
                assigned.add(b)
                if item[1] is not None:
                    for key in self.keys(item[1], env):
                        self.link(("b", b, ""), key)
                        self.link(("p", b, ""), key)
        for a in f.args.kwonlyargs:
            b = bid(a)
            item = kws.get(a.arg)
            if item is None and kwstar is not None:
                item = (kwstar, None)
            if item is None and b in f.defaults:
                self.provenance[b].add("callsites")
            if item is not None and b is not None:
                self.put(("p", b, ""), item[0])
                self.provenance[b].add("callsites")
                assigned.add(b)
                if item[1] is not None:
                    for key in self.keys(item[1], env):
                        self.link(("b", b, ""), key)
                        self.link(("p", b, ""), key)
        if f.args.vararg is not None:
            b = bid(f.args.vararg)
            tail = [t for t, _ in args[len(pos):]]
            t = self.p.add("tuple_of", elem=self.p.join_all(tail + [star])) if star is not None else self.p.add("tuple", elems=tail)
            self.put(("p", b, ""), t)  # type: ignore[arg-type]
            self.provenance[b].add("callsites")  # type: ignore[index]
        if f.args.kwarg is not None:
            b = bid(f.args.kwarg)
            accepted = {a.arg for a in list(f.args.args) + list(f.args.kwonlyargs)}
            vals = [t for name, (t, _) in kws.items() if name not in accepted]
            if kwstar is not None:
                vals.append(kwstar)
            self.put(("p", b, ""), self.p.add("dict", key=self.p.str if vals else self.p.never, value=self.p.join_all(vals)))  # type: ignore[arg-type]
            self.provenance[b].add("callsites")  # type: ignore[index]
        if f.raises:
            self.risky("call may raise: " + f.name)

    def callback(self, n: Optional[ast.AST], t: int, args: List[int], env: Env) -> int:
        targets = self.function_targets(n) if n is not None else []
        if targets:
            for s in targets:
                f = self.functions[s]
                f.escapes = True
                self.pass_arguments(f, [(a, None) for a in args], {}, None, None, env)
            return self.p.join_all(self.call_return(self.functions[s]) for s in targets)
        if n is not None and self.qname(n) in ("int", "float", "str", "bool", "bytes"):
            return getattr(self.p, self.qname(n))
        if self.p.kind(t) == "callable":
            return self.p.types[t]["ret"]
        return self.p.unknown("result of unknown callback")

    def call(self, n: ast.Call, env: Env) -> int:
        p = self.p
        fn_type = self.expr(n.func, env)
        args: List[Tuple[int, Optional[ast.AST]]] = []
        star: Optional[int] = None
        for a in n.args:
            if isinstance(a, ast.Starred):
                t = self.expr(a.value, env)
                self.expr(a, env)
                if p.kind(t) == "tuple" and star is None:
                    args.extend((v, None) for v in p.types[t]["elems"])
                else:
                    star = p.join(star if star is not None else p.never, self.element(t))
            else:
                t = self.expr(a, env)
                if star is None:
                    args.append((t, a))
                else:
                    star = p.join(star, t)
        kws: Dict[str, Tuple[int, Optional[ast.AST]]] = {}
        kwstar: Optional[int] = None
        for kw in n.keywords:
            t = self.expr(kw.value, env)
            if kw.arg is not None:
                kws[kw.arg] = (t, kw.value)
            elif isinstance(kw.value, ast.Dict) and all(isinstance(k, ast.Constant) and isinstance(k.value, str) for k in kw.value.keys):
                for key, value in zip(kw.value.keys, kw.value.values):
                    kws[key.value] = (self.expr(value, env), value)  # type: ignore[union-attr]
            else:
                value = p.types[t]["value"] if p.kind(t) == "dict" else p.unknown("expanded keyword value")
                kwstar = p.join(kwstar if kwstar is not None else p.never, value)
        values = [t for t, _ in args]
        named = {name: t for name, (t, _) in kws.items()}
        qn = self.qname(n.func)
        # Calls may invalidate refinements of globals/nonlocals captured elsewhere.
        for b in list(env):
            if isinstance(b, tuple):
                # Unknown call/impure method may invalidate a field refinement.
                env.pop(b, None)
                continue
            binding = self.table.bindings[b]
            if attr(binding, "captured", False) or attr(binding, "declared_global", False) or (self.current is not None and attr(binding, "scope") != self.current.scope):
                env.pop(b, None)
        if qn in ("typing.cast", "typing_extensions.cast") and len(n.args) >= 2:
            return self.annotation(n.args[0])
        if qn in ("typing.TypeVar", "typing_extensions.TypeVar", "TypeVar"):
            return p.instance("typing.TypeVar")
        manifest = self.api_for_member(n.func, env)
        if manifest is not None and manifest["kind"] in ("function", "constructor", "method", "class"):
            if manifest.get("raises", True):
                self.risky("library manifest call: " + manifest["python"])
            return self.api_result(manifest)
        if (star is not None or kwstar is not None) and ((self.api is None and qn in STDLIB) or qn in BUILTINS or isinstance(n.func, ast.Attribute)):
            if qn == "dict":
                result = self.dict_input(values[0]) if values else p.add("dict", key=p.never, value=p.never)
                if star is not None:
                    result = p.join(result, self.dict_input(star))
                if kwstar is not None:
                    result = p.join(result, p.add("dict", key=p.str, value=kwstar))
                if named:
                    result = p.join(result, p.add("dict", key=p.str, value=p.join_all(named.values())))
                return result
            if isinstance(n.func, ast.Attribute):
                receiver = self.expr(n.func.value, env)
                self.escape_mutable(n.func.value, receiver, env, "expanded method arguments: " + dotted(n.func))
            fixed = {"len": p.int, "int": p.int, "float": p.float, "str": p.str, "bool": p.bool, "bytes": p.bytes, "print": p.none, "any": p.bool, "all": p.bool, "isinstance": p.bool, "hasattr": p.bool}
            if qn in fixed:
                return fixed[qn]
            self.risky("expanded call arguments: " + (qn or dotted(n.func)))
            return p.unknown("expanded call arguments: " + (qn or dotted(n.func)))
        if self.api is None and qn in STDLIB:
            self.risky("library call: " + qn)
            return self.stdlib(qn, values, named, n)
        if qn in BUILTINS:
            self.risky("builtin call: " + qn)
            return self.builtin(qn, values, named, n, env)
        if isinstance(n.func, ast.Attribute):
            receiver = self.expr(n.func.value, env)
            results: List[int] = []
            handled = True
            for v in p.members(receiver):
                x = p.types[v]
                if x["k"] in ("instance", "class") and x["class_binding"] in self.classes:
                    ss = self.methods.get((x["class_binding"], n.func.attr), [])
                    if not ss or self.get(("f", x["class_binding"], n.func.attr)) != p.never or self.get(("h", x["class_binding"], "")) != p.never or any(self.unsafe_decorator(self.functions[s]) or self.functions[s].flavor == "property" for s in ss):
                        handled = False
                        break
                    for s in ss:
                        f = self.functions[s]
                        actual = list(args)
                        if f.flavor == "classmethod":
                            actual.insert(0, (p.add("class", class_binding=x["class_binding"], name=x["name"]), n.func.value))
                        elif x["k"] == "instance" and f.flavor not in ("staticmethod",):
                            actual.insert(0, (v, n.func.value))
                        self.pass_arguments(f, actual, kws, star, kwstar, env)
                        results.append(self.call_return(f))
                elif x["k"] in METHODS and n.func.attr in METHODS[x["k"]]:
                    self.method_write(n.func.value, v, n.func.attr, values, named, env)
                    results.append(self.method_result(v, n.func.attr, values, named))
                    self.risky("method call: " + x["k"] + "." + n.func.attr)
                elif self.api is None and x["k"] == "instance" and x["name"] in ("re.Pattern", "re.Match", "pathlib.Path", "io.TextIOBase", "io.BufferedIOBase", "os._Environ"):
                    results.append(self.external_method(v, n.func.attr, values, named))
                    self.risky("external method call: " + x["name"] + "." + n.func.attr)
                else:
                    handled = False
                    break
            if handled:
                return p.join_all(results)
        targets = self.function_targets(n.func)
        if targets and p.kind(fn_type) not in ("unknown", "dynamic"):
            for s in targets:
                self.pass_arguments(self.functions[s], args, kws, star, kwstar, env)
            return p.join_all(self.call_return(self.functions[s]) for s in targets)
        if p.kind(fn_type) == "class":
            x = p.types[fn_type]
            cb = x["class_binding"]
            if cb is None and x["name"] in BUILTINS:
                return self.builtin(x["name"], values, named, n, env)
            instance = p.instance(x["name"], binding=cb)
            if cb in self.classes:
                for s in self.methods.get((cb, "__init__"), []):
                    self.pass_arguments(self.functions[s], [(instance, None)] + args, kws, star, kwstar, env)
                if (cb, "__new__") in self.methods or self.classes[cb].keywords:
                    return p.unknown("custom construction: " + x["name"])
            self.risky("class construction: " + x["name"])
            return instance
        if p.kind(fn_type) == "callable":
            self.risky("indirect callable")
            return p.types[fn_type]["ret"]
        name = qn or dotted(n.func)
        self.risky("unknown call: " + name)
        for _, a in args + list(kws.values()):
            if a is not None:
                self.escape_mutable(a, self.expr(a, env), env, "mutable argument passed to unknown call: " + name)
        return p.unknown("result of call to unknown function: " + name)

    def escape_mutable(self, n: ast.AST, t: int, env: Env, reason: str) -> None:
        p = self.p
        for v in p.members(t):
            k = p.kind(v)
            u = p.unknown(reason)
            if k in ("list", "set"):
                self.mutate(n, p.add(k, elem=u), env, "unknown-call")
            elif k == "dict":
                self.mutate(n, p.add("dict", key=u, value=u), env, "unknown-call")
            elif k in ("instance", "class") and p.types[v]["class_binding"] in self.classes:
                self.put(("h", p.types[v]["class_binding"], ""), u)

    def method_write(self, receiver: ast.AST, t: int, name: str, args: List[int], kws: Dict[str, int], env: Env) -> None:
        p, x = self.p, self.p.types[t]
        k = x["k"]
        shape = p.never
        if k == "list":
            if name == "append" and args:
                shape = p.add("list", elem=args[0])
            elif name == "insert" and len(args) > 1:
                shape = p.add("list", elem=args[1])
            elif name == "extend" and args:
                shape = p.add("list", elem=self.element(args[0]))
        elif k == "set":
            if name == "add" and args:
                shape = p.add("set", elem=args[0])
            elif name in ("update", "intersection_update", "symmetric_difference_update"):
                shape = p.add("set", elem=p.join_all(self.element(v) for v in args))
        elif k == "dict":
            if name == "setdefault" and args:
                shape = p.add("dict", key=args[0], value=args[1] if len(args) > 1 else p.none)
            elif name == "update":
                shape = self.dict_input(args[0]) if args else p.add("dict", key=p.never, value=p.never)
                if kws:
                    shape = p.join(shape, p.add("dict", key=p.str, value=p.join_all(kws.values())))
        if shape != p.never:
            self.mutate(receiver, shape, env, "mutation:" + name)

    def dict_input(self, t: int) -> int:
        p = self.p
        if p.kind(t) == "dict":
            return t
        if p.kind(t) == "union":
            return p.join_all(self.dict_input(v) for v in p.members(t))
        elem = self.element(t)
        if elem == p.never:
            return p.add("dict", key=p.never, value=p.never)
        x = p.types[elem]
        if x["k"] == "tuple" and len(x["elems"]) == 2:
            return p.add("dict", key=x["elems"][0], value=x["elems"][1])
        u = p.unknown("dict input is not a known mapping or pair iterable")
        return p.add("dict", key=u, value=u)

    def method_result(self, t: int, name: str, args: List[int], kws: Dict[str, int]) -> int:
        p, x = self.p, self.p.types[t]
        rule = METHODS.get(x["k"], {}).get(name, "")
        if rule in ("none", "bool", "int", "float", "str", "bytes"):
            return getattr(p, rule)
        if rule == "self":
            return t
        if rule == "elem":
            return x["elem"]
        if rule.startswith("list_"):
            return p.add("list", elem=getattr(p, rule[5:]))
        if rule.startswith("triple_"):
            return p.add("tuple", elems=[getattr(p, rule[7:])] * 3)
        if rule == "set_join":
            return p.add("set", elem=p.join_all([x["elem"]] + [self.element(v) for v in args]))
        if rule in ("dict_get", "dict_pop"):
            default = args[1] if len(args) > 1 else (p.none if rule == "dict_get" else p.never)
            return p.join(x["value"], default)
        if rule == "dict_item":
            return p.add("tuple", elems=[x["key"], x["value"]])
        if rule in ("dict_keys", "dict_values", "dict_items"):
            element = x["key"] if rule == "dict_keys" else x["value"] if rule == "dict_values" else p.add("tuple", elems=[x["key"], x["value"]])
            return p.instance("collections.abc.Iterable", [element])
        return p.unknown("unknown method result: " + x["k"] + "." + name)

    def builtin(self, name: str, args: List[int], kws: Dict[str, int], n: ast.Call, env: Env) -> int:
        p = self.p
        keyword_positions = {"round": ("number", "ndigits"), "pow": ("base", "exp", "mod"), "enumerate": ("iterable", "start")}
        args = list(args)
        for key in keyword_positions.get(name, ())[len(args):]:
            if key in kws:
                args.append(kws[key])
            else:
                break
        first = args[0] if args else p.never
        if name in ("int", "float", "str", "bool", "bytes"):
            return getattr(p, name)
        if name in ("len", "ord"):
            return p.int
        if name in ("any", "all", "isinstance", "hasattr"):
            return p.bool
        if name in ("repr", "input", "chr", "hex", "bin"):
            return p.str
        if name == "print":
            return p.none
        if name == "range":
            return p.instance("range", [p.int])
        if name in ("object", "complex", "frozenset"):
            return p.instance(name, [self.element(first)] if name == "frozenset" else [])
        if name in ("list", "set", "sorted"):
            elem = self.element(first)
            if "key" in kws:
                kw_node = next((kw.value for kw in n.keywords if kw.arg == "key"), None)
                self.callback(kw_node, kws["key"], [elem], env)
            return p.add("set" if name == "set" else "list", elem=elem)
        if name == "tuple":
            if not args:
                return p.add("tuple", elems=[])
            if p.kind(first) == "tuple":
                return first
            return p.add("tuple_of", elem=self.element(first))
        if name == "dict":
            result = self.dict_input(first)
            return p.join(result, p.add("dict", key=p.str, value=p.join_all(kws.values()))) if kws else result
        if name in ("iter", "reversed"):
            if name == "iter" and len(args) == 2:
                return self.iterator(self.callback(n.args[0], first, [], env))
            return self.iterator(self.element(first))
        if name == "enumerate":
            return self.iterator(p.add("tuple", elems=[p.int, self.element(first)]))
        if name == "zip":
            return self.iterator(p.add("tuple", elems=[self.element(v) for v in args]))
        if name == "map":
            return self.iterator(self.callback(n.args[0] if n.args else None, first, [self.element(v) for v in args[1:]], env))
        if name == "filter":
            elem = self.element(args[1]) if len(args) > 1 else p.never
            if first != p.none:
                self.callback(n.args[0] if n.args else None, first, [elem], env)
            return self.iterator(p.without_none(elem) if first == p.none else elem)
        if name == "next":
            return p.join(self.element(first), args[1] if len(args) > 1 else p.never)
        if name == "sum":
            start = args[1] if len(args) > 1 else kws.get("start", p.int)
            elem = self.element(first)
            if elem == p.never:
                return start
            if p.kind(first) in ("list", "tuple", "tuple_of") and elem in (p.int, p.float):
                # Assumption for non-empty numeric iterables. An empty iterable
                # with the implicit int(0) start is a documented exception.
                if elem == p.float and start == p.int:
                    return p.float
                if elem == p.int and start == p.int:
                    return p.int
            return p.join(start, self.binary(ast.Add(), start, elem))
        if name in ("min", "max"):
            result = self.element(first) if len(args) == 1 else p.join_all(args)
            if "key" in kws:
                self.callback(next((kw.value for kw in n.keywords if kw.arg == "key"), None), kws["key"], [result], env)
            return p.join(result, kws.get("default", p.never))
        if name == "abs":
            return p.join_all(p.int if p.kind(v) in ("bool", "int") else p.float if p.kind(v) == "float" or (p.kind(v) == "instance" and p.types[v]["name"] == "complex") else v if p.kind(v) in ("never", "unknown", "dynamic") else p.unknown("overloaded abs: " + p.render(v)) for v in p.members(first))
        if name == "round":
            ndigits = args[1] if len(args) > 1 else kws.get("ndigits", p.none)
            return p.join_all(p.int if p.kind(v) in ("bool", "int") or (p.kind(v) == "float" and ndigits == p.none) else p.float if p.kind(v) == "float" and ndigits == p.int else p.join(p.int, p.float) if p.kind(v) == "float" else p.unknown("overloaded round: " + p.render(v)) for v in p.members(first))
        if name == "divmod" and len(args) >= 2:
            t = self.binary(ast.FloorDiv(), args[0], args[1])
            return p.add("tuple", elems=[t, t])
        if name == "pow" and len(args) >= 2:
            return p.int if (len(args) > 2 or "mod" in kws) and all(p.kind(v) in ("int", "bool") for v in args + ([kws["mod"]] if "mod" in kws else [])) else self.binary(ast.Pow(), args[0], args[1], n.args[1] if len(n.args) > 1 else None)
        if name == "setattr" and len(args) == 3:
            field_name = n.args[1].value if len(n.args) > 1 and isinstance(n.args[1], ast.Constant) and isinstance(n.args[1].value, str) else None
            for v in p.members(first):
                x = p.types[v]
                if x["k"] in ("instance", "class") and x["class_binding"] in self.classes:
                    self.put(("f", x["class_binding"], field_name), args[2]) if field_name is not None else self.put(("h", x["class_binding"], ""), p.unknown("setattr with nonliteral attribute name"))
            return p.none
        if name == "getattr":
            if len(n.args) > 1 and isinstance(n.args[1], ast.Constant) and isinstance(n.args[1].value, str):
                t = p.join_all(self.attribute(v, n.args[1].value) for v in p.members(first))
                return p.join(t, args[2] if len(args) > 2 else p.never)
            return p.unknown("getattr with nonliteral attribute name")
        if name == "type":
            return p.join_all(p.add("class", class_binding=p.types[v].get("class_binding"), name=p.types[v].get("name", {"none": "NoneType", "callable": "function", "tuple_of": "tuple"}.get(p.kind(v), p.kind(v)))) if p.kind(v) not in ("never", "unknown", "dynamic") else v for v in p.members(first)) if len(args) == 1 else p.unknown("dynamic class construction")
        if name == "open":
            mode: Optional[ast.AST] = n.args[1] if len(n.args) > 1 else next((k.value for k in n.keywords if k.arg == "mode"), None)
            text = p.instance("io.TextIOBase")
            binary = p.instance("io.BufferedIOBase")
            if mode is None:
                return text
            if isinstance(mode, ast.Constant) and isinstance(mode.value, str):
                if "b" in mode.value:
                    buffering = n.args[2] if len(n.args) > 2 else next((k.value for k in n.keywords if k.arg == "buffering"), None)
                    if isinstance(buffering, ast.Constant) and buffering.value == 0:
                        return p.instance("io.RawIOBase")
                    if buffering is not None and not isinstance(buffering, ast.Constant):
                        return p.join(binary, p.instance("io.RawIOBase"))
                    return binary
                return text
            return p.join(text, binary)
        return p.unknown("unsupported builtin call: " + name)

    def stdlib(self, name: str, args: List[int], kws: Dict[str, int], n: ast.Call) -> int:
        p, rule = self.p, STDLIB[name]
        if rule in ("str", "bool", "float"):
            return getattr(p, rule)
        if rule == "json":
            return p.dynamic("JSON value")
        if rule == "path_join":
            return p.bytes if args and all(t == p.bytes for t in args) else p.str if args and all(t == p.str for t in args) else p.join(p.str, p.bytes)
        if rule == "environ_get":
            return p.join(p.str, args[1] if len(args) > 1 else kws.get("default", p.none))
        if rule == "connection" and ("factory" in kws or len(args) > 5):
            return p.unknown("custom sqlite connection factory")
        if rule in ("datetime", "path", "connection"):
            return p.instance({"datetime": "datetime.datetime", "path": "pathlib.Path", "connection": "sqlite3.Connection"}[rule])
        pattern = args[0] if args else kws.get("pattern", p.unknown("missing regex pattern"))
        elem = p.bytes if pattern == p.bytes else p.str if pattern == p.str else p.join(p.str, p.bytes)
        if rule == "re_compile":
            return p.instance("re.Pattern", [elem])
        if rule == "re_match":
            return p.join(p.instance("re.Match", [elem]), p.none)
        if rule == "re_sub":
            return args[2] if len(args) > 2 else kws.get("string", elem)
        if rule == "re_findall":
            return p.add("list", elem=p.join(elem, p.add("tuple_of", elem=elem)))
        return p.unknown("unsupported library rule: " + name)

    def external_method(self, t: int, name: str, args: List[int], kws: Dict[str, int]) -> int:
        p, x = self.p, self.p.types[t]
        cls = x["name"]
        elem = x["args"][0] if x["args"] else p.unknown("unparameterized external instance: " + cls)
        if cls == "os._Environ" and name == "get":
            return p.join(p.str, args[1] if len(args) > 1 else kws.get("default", p.none))
        if cls == "re.Pattern":
            if name in ("match", "search", "fullmatch"):
                return p.join(p.instance("re.Match", [elem]), p.none)
            if name == "findall":
                return p.add("list", elem=p.join(elem, p.add("tuple_of", elem=elem)))
            if name in ("sub", "split"):
                return elem if name == "sub" else p.add("list", elem=p.join(elem, p.none))
        if cls == "re.Match":
            if name == "group":
                v = p.join(elem, p.none)
                return v if len(args) <= 1 else p.add("tuple", elems=[v] * len(args))
            if name == "groups":
                return p.add("tuple_of", elem=p.join(elem, args[0] if args else p.none))
            if name in ("start", "end"):
                return p.int
            if name == "span":
                return p.add("tuple", elems=[p.int, p.int])
        if cls == "pathlib.Path":
            if name in ("exists", "is_file", "is_dir", "is_absolute"):
                return p.bool
            if name in ("resolve", "absolute", "joinpath", "with_name", "with_suffix"):
                return t
            if name in ("read_text", "as_posix"):
                return p.str
            if name == "read_bytes":
                return p.bytes
            if name in ("write_text", "write_bytes"):
                return p.int
            if name in ("iterdir", "glob", "rglob"):
                return self.iterator(t)
        if cls in ("io.TextIOBase", "io.BufferedIOBase", "io.RawIOBase"):
            value = p.str if cls == "io.TextIOBase" else p.bytes
            if name in ("read", "readline"):
                return value
            if name == "readlines":
                return p.add("list", elem=value)
            if name in ("write", "tell", "seek"):
                return p.int
            if name in ("close", "flush", "writelines"):
                return p.none
        return p.unknown("unknown external method: " + cls + "." + name)

    def assign(self, n: ast.AST, t: int, env: Env, why: str, source: Optional[ast.AST] = None) -> None:
        p = self.p
        n._type = p.join(getattr(n, "_type", p.never), t)  # type: ignore[attr-defined]
        if isinstance(n, ast.Name):
            # RHS alias analysis must use the pre-write environment. In
            # `node = node.next`, inspecting `node.next` *after* updating the
            # binding pollutes its expression type with the post-write union.
            source_keys = self.keys(source, env) if source is not None else []
            b = bid(n)
            self.bind(b, t, why)
            if b is not None:
                # Narrowing of x.attr is invalid after any assignment to x.
                for key in list(env):
                    if isinstance(key, tuple) and key[:2] == ("attr", b):
                        del env[key]
                env[b] = self.declared[b] if self.declared_first and b in self.declared else t
                if source is not None:
                    for key in source_keys:
                        self.link(("b", b, ""), key)
                    targets = set(self.function_targets(source))
                    if not targets.issubset(self.targets[b]) and not self.frozen:
                        self.targets[b].update(targets)
                        self.changed = True
        elif isinstance(n, ast.Starred):
            self.assign(n.value, t, env, why, source)
        elif isinstance(n, (ast.Tuple, ast.List)):
            elems = p.types[t].get("elems") if p.kind(t) == "tuple" else None
            star = next((i for i, x in enumerate(n.elts) if isinstance(x, ast.Starred)), None)
            for i, target in enumerate(n.elts):
                if elems is not None and star is None:
                    value = elems[i] if i < len(elems) else p.unknown("unpacking arity mismatch")
                elif elems is not None and star is not None:
                    if i < star:
                        value = elems[i] if i < len(elems) else p.unknown("unpacking arity mismatch")
                    elif i == star:
                        stop = len(elems) - (len(n.elts) - i - 1)
                        value = p.add("list", elem=p.join_all(elems[i:max(i, stop)]))
                    else:
                        j = len(elems) - (len(n.elts) - i)
                        value = elems[j] if 0 <= j < len(elems) else p.unknown("unpacking arity mismatch")
                else:
                    value = self.element(t)
                    if isinstance(target, ast.Starred):
                        value = p.add("list", elem=value)
                self.assign(target, value, env, why)
        elif isinstance(n, ast.Attribute):
            for key in self.keys(n, env):
                self.put(key, t)
                if source is not None:
                    for other in self.keys(source, env):
                        self.link(key, other)
        elif isinstance(n, ast.Subscript):
            base = self.expr(n.value, env)
            index = self.expr(n.slice, env)
            for v in p.members(base):
                x = p.types[v]
                if x["k"] == "list":
                    shape = p.add("list", elem=self.element(t) if isinstance(n.slice, ast.Slice) else t)
                    self.mutate(n.value, shape, env, why)
                elif x["k"] == "dict":
                    self.mutate(n.value, p.add("dict", key=index, value=t), env, why)
            self.risky("container assignment")

    def narrow(self, n: ast.AST, env: Env) -> Tuple[Optional[Env], Optional[Env]]:
        p = self.p
        yes, no = dict(env), dict(env)
        if isinstance(n, ast.Constant):
            return (yes, None) if bool(n.value) else (None, no)
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.Not):
            a, b = self.narrow(n.operand, env)
            return b, a
        if isinstance(n, ast.BoolOp):
            active: Optional[Env] = dict(env)
            exits: Optional[Env] = None
            for child in n.values:
                if active is None:
                    break
                a, b = self.narrow(child, active)
                if isinstance(n.op, ast.And):
                    exits = self.env_join(exits, b)
                    active = a
                else:
                    exits = self.env_join(exits, a)
                    active = b
            return (active, exits) if isinstance(n.op, ast.And) else (exits, active)
        target: Optional[ast.Name] = n if isinstance(n, ast.Name) else None
        mode = "truth"
        expected = p.never
        if isinstance(n, ast.Compare) and len(n.ops) == 1 and isinstance(n.ops[0], (ast.Is, ast.IsNot)):
            a, b = n.left, n.comparators[0]
            if isinstance(a, ast.Constant) and a.value is None:
                a, b = b, a
            if isinstance(a, ast.Name) and isinstance(b, ast.Constant) and b.value is None:
                target, mode = a, "none" if isinstance(n.ops[0], ast.Is) else "not_none"
        if isinstance(n, ast.Call) and self.qname(n.func) == "isinstance" and len(n.args) == 2 and isinstance(n.args[0], ast.Name):
            target, mode = n.args[0], "instance"
            candidates = n.args[1].elts if isinstance(n.args[1], ast.Tuple) else [n.args[1]]
            if not all(isinstance(c, (ast.Name, ast.Attribute)) and (self.qname(c) in ("object", "int", "float", "str", "bytes", "bool", "list", "dict", "set", "tuple") or bid(c) in self.classes) for c in candidates):
                return yes, no
            expected = p.join_all(self.annotation(c) for c in candidates)
            if any(self.qname(c) == "object" for c in candidates):
                return yes, None
            if p.int in p.members(expected):
                expected = p.join(expected, p.bool)
        if target is None or bid(target) is None:
            # Attribute truthiness can narrow the value of a field, not the
            # receiver: while node.next: node = node.next. Track the temporary
            # refinement in the branch environment and kill it on receiver
            # writes. Never conclude that `node` itself is None.
            if isinstance(n, ast.Attribute):
                key = self.attr_key(n)
                if key is not None:
                    receiver_type = self.read_name(n.value, env)
                    old_attr = self.p.join_all(self.attribute(v, n.attr)
                                               for v in p.members(receiver_type))
                    yt, nt = p.without_none(old_attr), old_attr
                    if yt != p.never:
                        yes[key] = yt
                    if nt != p.never:
                        no[key] = nt
                    return (yes if yt != p.never else None, no if nt != p.never else None)
            return yes, no
        b = bid(target)
        old = self.read_name(target, env)
        if mode in ("none", "not_none"):
            present = p.none if p.kind(old) in ("unknown", "dynamic", "never") or p.none in p.members(old) else p.never
            absent = p.without_none(old)
            yt, nt = (present, absent) if mode == "none" else (absent, present)
        elif mode == "instance":
            if p.kind(old) in ("unknown", "dynamic", "never"):
                yt, nt = expected, old
            else:
                matches = set(p.members(expected))
                kinds = {p.kind(v) for v in matches}
                if "tuple_of" in kinds:
                    kinds.add("tuple")
                def matches_type(v: int) -> bool:
                    return v in matches or (p.kind(v) in kinds and p.kind(v) in ("list", "set", "dict", "tuple", "tuple_of"))
                # Exact primitive alternatives; custom subclass relationships unknown.
                yt = p.join_all(v for v in p.members(old) if matches_type(v) or p.kind(v) == "instance")
                nt = p.join_all(v for v in p.members(old) if not matches_type(v) or p.kind(v) == "instance")
        else:
            yt, nt = p.without_none(old), old
        yes[b], no[b] = yt, nt  # type: ignore[index]
        return (None if yt == p.never else yes, None if nt == p.never else no)

    def block(self, statements: Sequence[ast.stmt], env: Env) -> Flow:
        out = Flow(dict(env), self.p.never)
        for statement in statements:
            if out.normal is None:
                break
            result = self.statement(statement, out.normal)
            out.normal = result.normal
            out.returns = self.p.join(out.returns, result.returns)
            out.breaks = self.env_join(out.breaks, result.breaks)
            out.continues = self.env_join(out.continues, result.continues)
            out.raised |= result.raised
        return out

    def combine(self, a: Flow, b: Flow) -> Flow:
        return Flow(self.env_join(a.normal, b.normal), self.p.join(a.returns, b.returns),
                    self.env_join(a.breaks, b.breaks), self.env_join(a.continues, b.continues), a.raised or b.raised)

    def enum_member_type(self, target: ast.AST, original: int) -> int:
        cb = self.active_class
        if cb not in self.enum_classes or not isinstance(target, ast.Name):
            return original
        name = target.id
        # The Enum metaclass turns ordinary class-body assignments into
        # members, including aliases and auto()-created members.
        if name.startswith("_") or name.startswith("__"):
            return original
        # During class-body execution the raw rhs remains observable in the
        # temporary namespace. EnumMeta later replaces it with a member.
        return self.p.join(original, self.p.instance(self.classes[cb].name, binding=cb))

    def statement(self, n: ast.stmt, env: Env) -> Flow:
        p = self.p
        if isinstance(n, ast.Assign):
            t = self.expr(n.value, env)
            why = "literal" if isinstance(n.value, (ast.Constant, ast.List, ast.Set, ast.Dict, ast.Tuple)) else "return-of:" + dotted(n.value.func) if isinstance(n.value, ast.Call) else "assignment"
            for target in n.targets:
                value = self.enum_member_type(target, t) if self.active_class is not None else t
                self.assign(target, value, env, why, n.value)
        elif isinstance(n, ast.AnnAssign):
            if n.value is not None:
                t = self.expr(n.value, env)
                self.assign(n.target, self.enum_member_type(n.target, t) if self.active_class is not None else t,
                            env, "assignment", n.value)
        elif isinstance(n, ast.AugAssign):
            old, value = self.expr(n.target, env), self.expr(n.value, env)
            t = self.binary(n.op, old, value, n.value)
            if isinstance(n.op, ast.Add) and p.kind(old) == "list":
                t = p.add("list", elem=p.join(p.types[old]["elem"], self.element(value)))
            self.assign(n.target, t, env, "augassign")
            if p.kind(old) in ("list", "set", "dict"):
                self.mutate(n.target, t, env, "augassign")
        elif isinstance(n, ast.Expr):
            self.expr(n.value, env)
        elif isinstance(n, ast.Return):
            value = self.expr(n.value, env)
            if self.current is not None and n.value is not None:
                for key in self.keys(n.value, env):
                    self.link(("r", self.current.scope, ""), key)
            return Flow(None, value)
        elif isinstance(n, ast.Raise):
            self.expr(n.exc, env)
            self.expr(n.cause, env)
            self.risky("reachable raise")
            return Flow(None, p.never, raised=True)
        elif isinstance(n, ast.Assert):
            self.expr(n.test, env)
            yes, no = self.narrow(n.test, env)
            if no is not None:
                self.expr(n.msg, no)
                self.risky("assertion")
            return Flow(yes, p.never, raised=no is not None)
        elif isinstance(n, ast.If):
            self.expr(n.test, env)
            yes, no = self.narrow(n.test, env)
            return self.combine(self.block(n.body, yes) if yes is not None else Flow(None), self.block(n.orelse, no) if no is not None else Flow(None))
        elif isinstance(n, (ast.For, ast.AsyncFor, ast.While)):
            local = dict(env)
            # A loop header includes values from previous iterations, even when a
            # source-level assignment before the loop supplied a narrower value.
            for child in ast.walk(n):
                if isinstance(child, ast.Name) and isinstance(child.ctx, ast.Store) and bid(child) is not None:
                    b = bid(child)
                    local[b] = p.join(local.get(b, p.never), self.get(("b", b, "")))  # type: ignore[index,arg-type]
            if isinstance(n, ast.While):
                self.expr(n.test, local)
                yes, exhausted = self.narrow(n.test, local)
            else:
                value = self.expr(n.iter, local)
                self.assign(n.target, self.element(value), local, "for-over:" + p.kind(value))
                yes, exhausted = local, dict(env)
                self.risky("iteration")
            body = self.block(n.body, yes) if yes is not None else Flow(None)
            if not (isinstance(n, ast.While) and isinstance(n.test, ast.Constant) and bool(n.test.value)):
                exhausted = self.env_join(exhausted, self.env_join(body.normal, body.continues))
            tail = self.block(n.orelse, exhausted) if exhausted is not None else Flow(None)
            return Flow(self.env_join(body.breaks, tail.normal), p.join(body.returns, tail.returns), tail.breaks, tail.continues, body.raised or tail.raised)
        elif isinstance(n, ast.Break):
            return Flow(None, p.never, breaks=dict(env))
        elif isinstance(n, ast.Continue):
            return Flow(None, p.never, continues=dict(env))
        elif isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
            self.definition(n, env)
        elif isinstance(n, ast.ClassDef):
            for x in list(n.bases) + [kw.value for kw in n.keywords] + list(n.decorator_list):
                self.expr(x, env)
            cb = bid(n)
            t = p.add("class", class_binding=cb, name=n.name)
            if n.decorator_list:
                t = p.unknown("decorated class value: " + n.name)
            self.bind(cb, t, "class-definition")
            previous_class = self.active_class
            self.active_class = cb
            try:
                class_body = self.block(n.body, dict(env))
            finally:
                self.active_class = previous_class
            if class_body.normal is not None:
                class_scope = getattr(n, "_scope_id")
                for b, value in class_body.normal.items():
                    if isinstance(b, tuple):
                        continue
                    if attr(self.table.bindings[b], "scope") != class_scope:
                        env[b] = value
            if cb is not None:
                env[cb] = t
        elif isinstance(n, (ast.Import, ast.ImportFrom)):
            for a in n.names:
                b = bid(a)
                if b is None:
                    continue
                name = self.imports.get(b, a.name)
                if isinstance(n, ast.Import):
                    t = p.add("module", name=name)
                elif self.api_entry(name) is not None:
                    t = self.api_symbol(self.api_entry(name))
                elif self.api is None and name in ("pathlib.Path", "datetime.datetime"):
                    t = p.add("class", class_binding=None, name=name)
                elif name in ENUM_BASES:
                    t = p.add("class", class_binding=None, name=name)
                elif name in ("typing.TypeVar", "typing_extensions.TypeVar", "typing.ParamSpec",
                              "typing.TypeVarTuple", "typing_extensions.ParamSpec", "typing_extensions.TypeVarTuple"):
                    t = p.add("class", class_binding=None, name=name)
                elif name in STDLIB or name in ("typing.cast", "typing_extensions.cast"):
                    t = p.add("callable", params=[], ret=p.unknown("imported callable signature: " + name), func_binding=None)
                elif name in ("os.path", "os.environ"):
                    t = p.add("module", name=name) if name == "os.path" else p.instance("os._Environ", [p.str, p.str])
                else:
                    t = p.unknown("imported value without signature: " + name)
                external = self.external_type(name)
                if external is not None:
                    t = external
                self.bind(b, t, "import")
                env[b] = t
        elif isinstance(n, (ast.With, ast.AsyncWith)):
            local = dict(env)
            for item in n.items:
                t = self.expr(item.context_expr, local)
                x = p.types[t]
                if not (x["k"] == "instance" and x["name"] in ("io.TextIOBase", "io.BufferedIOBase", "io.RawIOBase")):
                    t = p.unknown("context manager enter result: " + dotted(item.context_expr))
                if item.optional_vars is not None:
                    self.assign(item.optional_vars, t, local, "context-manager")
            self.risky("context manager")
            result = self.block(n.body, local)
            # __exit__ can swallow an exception and resume after the with.
            known_io = all(self.p.kind(getattr(item.context_expr, "_type", p.never)) == "instance" and self.p.types[getattr(item.context_expr, "_type")]["name"] in ("io.TextIOBase", "io.BufferedIOBase", "io.RawIOBase") for item in n.items)
            if not known_io:
                result.normal = self.env_join(result.normal, local)
            return result
        elif isinstance(n, ast.Try) or type(n).__name__ == "TryStar":
            body = self.block(n.body, dict(env))
            result = Flow(None, body.returns, body.breaks, body.continues, body.raised)
            if body.normal is not None:
                result = self.combine(result, self.block(n.orelse, body.normal))
            for handler in n.handlers:
                local = dict(env)
                # An exception can occur after any write in the protected body.
                for child in ast.walk(n):
                    if isinstance(child, ast.Name) and bid(child) is not None:
                        b = bid(child)
                        local[b] = self.get(("b", b, ""))  # type: ignore[index,arg-type]
                if handler.type is not None:
                    self.expr(handler.type, local)
                if bid(handler) is not None:
                    if type(n).__name__ == "TryStar":
                        # A split subgroup of ordinary Exception subclasses
                        # is an ExceptionGroup; BaseException-only handlers
                        # such as KeyboardInterrupt get BaseExceptionGroup.
                        # Unknown user exception bases require both cases.
                        names = (handler.type.elts if isinstance(handler.type, ast.Tuple)
                                 else [handler.type]) if handler.type is not None else []
                        shorts = [(self.qname(item) or dotted(item)).rsplit(".", 1)[-1]
                                  for item in names]
                        base_only = {"BaseException", "BaseExceptionGroup", "KeyboardInterrupt",
                                     "SystemExit", "GeneratorExit"}
                        ordinary = {"Exception", "ExceptionGroup", "ValueError", "TypeError", "OSError",
                                    "RuntimeError", "LookupError", "KeyError", "IndexError", "NameError",
                                    "AttributeError", "StopIteration", "StopAsyncIteration", "ZeroDivisionError",
                                    "ArithmeticError", "AssertionError", "ImportError", "ModuleNotFoundError",
                                    "SyntaxError", "UnicodeError", "UnicodeDecodeError", "UnicodeEncodeError",
                                    "NotImplementedError", "EOFError", "FileNotFoundError", "PermissionError",
                                    "ConnectionError", "TimeoutError", "MemoryError", "RecursionError"}
                        if shorts and all(name in ordinary for name in shorts):
                            t = p.instance("ExceptionGroup")
                        elif shorts and all(name in base_only for name in shorts):
                            t = p.instance("BaseExceptionGroup")
                        else:
                            t = p.join(p.instance("ExceptionGroup"), p.instance("BaseExceptionGroup"))
                    else:
                        t = self.annotation(handler.type) if handler.type is not None else p.instance("BaseException")
                    self.bind(bid(handler), t, "except-handler")
                    local[bid(handler)] = t  # type: ignore[index]
                result = self.combine(result, self.block(handler.body, local))
            if n.finalbody:
                final_env = self.env_join(env, self.env_join(result.normal, self.env_join(result.breaks, result.continues))) or dict(env)
                for b in list(final_env):
                    final_env[b] = p.join(final_env[b], self.get(("b", b, "")))
                final = self.block(n.finalbody, final_env)
                if final.normal is None:
                    return final
                return Flow(final.normal if result.normal is not None else None, p.join(result.returns, final.returns),
                            self.env_join(result.breaks, final.breaks), self.env_join(result.continues, final.continues), result.raised or final.raised)
            return result
        elif type(n).__name__ == "Match":
            subject = self.expr(n.subject, env)
            result = Flow(None)
            exhaustive = False
            for case in n.cases:
                local = dict(env)
                self.pattern(case.pattern, subject, local)
                if case.guard is not None:
                    self.expr(case.guard, local)
                    yes, _ = self.narrow(case.guard, local)
                    if yes is None:
                        continue
                    local = yes
                if type(case.pattern).__name__ == "MatchAs" and case.pattern.pattern is None and case.guard is None:
                    exhaustive = True
                result = self.combine(result, self.block(case.body, local))
            if not exhaustive:
                result.normal = self.env_join(result.normal, env)
            return result
        elif type(n).__name__ == "TypeAlias":
            self.assign(n.name, p.instance("typing.TypeAliasType"), env, "type-alias")
        elif isinstance(n, ast.Delete):
            for target in n.targets:
                if isinstance(target, ast.Name) and bid(target) is not None:
                    env.pop(bid(target), None)
                else:
                    self.expr(target, env)
        elif not isinstance(n, (ast.Pass, ast.Global, ast.Nonlocal)):
            for c in ast.iter_child_nodes(n):
                if isinstance(c, ast.expr):
                    self.expr(c, env)
        return Flow(env, p.never)

    def pattern(self, n: ast.AST, t: int, env: Env) -> None:
        p, kind = self.p, type(n).__name__
        if bid(n) is not None:
            value = p.add("list", elem=self.element(t)) if kind == "MatchStar" else t
            if kind == "MatchMapping":
                value = t
            self.bind(bid(n), value, "match-capture")
            env[bid(n)] = value  # type: ignore[index]
        if kind == "MatchSequence":
            es = p.types[t].get("elems") if p.kind(t) == "tuple" else None
            star = next((i for i, v in enumerate(n.patterns) if type(v).__name__ == "MatchStar"), None)
            for i, child in enumerate(n.patterns):
                if es is not None and star is None and i < len(es):
                    value = es[i]
                else:
                    value = self.element(t)
                if type(child).__name__ == "MatchStar":
                    value = p.add("list", elem=value)
                    if bid(child) is not None:
                        self.bind(bid(child), value, "match-capture")
                        env[bid(child)] = value  # type: ignore[index]
                else:
                    self.pattern(child, value, env)
        elif kind == "MatchMapping":
            value = p.types[t]["value"] if p.kind(t) == "dict" else p.unknown("mapping pattern value")
            for key in n.keys:
                self.expr(key, env)
            for child in n.patterns:
                self.pattern(child, value, env)
        elif kind == "MatchClass":
            self.expr(n.cls, env)
            for child in n.patterns:
                self.pattern(child, p.unknown("positional class pattern"), env)
            for name, child in zip(n.kwd_attrs, n.kwd_patterns):
                self.pattern(child, self.attribute(t, name), env)
        elif kind == "MatchValue":
            self.expr(n.value, env)
        elif kind == "MatchOr":
            for child in n.patterns:
                self.pattern(child, t, env)
        elif kind == "MatchAs" and n.pattern is not None:
            self.pattern(n.pattern, t, env)

    def iteration(self) -> None:
        for n in self.nodes:
            if isinstance(n, (ast.expr, ast.Slice)):
                n._type = self.p.never  # type: ignore[attr-defined]
        self.current = None
        self.block(self.tree.body, {})
        for f in self.functions.values():
            self.current = f
            local: Env = {}
            for i, a in enumerate(f.params):
                b = bid(a)
                if b is None:
                    continue
                if i == 0 and f.owner is not None and f.flavor not in ("staticmethod",):
                    cls = self.classes[f.owner]
                    receiver = self.p.add("class", class_binding=f.owner, name=cls.name) if f.flavor == "classmethod" else self.p.instance(cls.name, binding=f.owner)
                    self.put(("p", b, ""), receiver)
                    self.provenance[b].add("method-receiver")
                self.link(("b", b, ""), ("p", b, ""))
                value = self.get(("p", b, ""))
                self.bind(b, value)
                local[b] = value
            if isinstance(f.node, ast.Lambda):
                ret = self.expr(f.node.body, local)
                for key in self.keys(f.node.body, local):
                    self.link(("r", f.scope, ""), key)
            else:
                result = self.block(f.node.body, local)
                ret = self.p.join(result.returns, self.p.none if result.normal is not None else self.p.never)
            self.put(("r", f.scope, ""), ret)
        self.current = None

    def solve_phase(self) -> None:
        for _ in range(MAX_ROUNDS):
            self.changed = False
            self.rounds += 1
            self.iteration()
            if not self.changed:
                return
        self.limit_hit = True
        top = self.p.dynamic("fixed point iteration limit")
        for key in list(self.cells):
            self.cells[key] = top
        for b in self.table.bindings:
            self.cells["b", attr(b, "id"), ""] = top
        for f in self.functions.values():
            self.cells["r", f.scope, ""] = top
            self.cells["y", f.scope, ""] = top
            for a in f.params:
                if bid(a) is not None:
                    self.cells["p", bid(a), ""] = top  # type: ignore[index]
        self.frozen = True
        self.iteration()

    def finish(self) -> TypeFacts:
        p = self.p
        self.solve_phase()
        if not self.limit_hit:
            for f in self.functions.values():
                for a in f.params:
                    b = bid(a)
                    if b is not None and self.get(("p", b, "")) == p.never:
                        reason = "parameter with no value evidence" if b in self.declared else "unannotated parameter with no call sites"
                        self.put(("p", b, ""), p.unknown(reason + ": " + f.name + "." + a.arg))
                if f.has_return and self.get(("r", f.scope, "")) == p.never:
                    self.put(("r", f.scope, ""), p.unknown("return with no value evidence: " + f.name))
            for b in self.table.bindings:
                i = attr(b, "id")
                if self.get(("b", i, "")) == p.never and not attr(b, "is_param", False):
                    self.put(("b", i, ""), p.unknown("binding with no value evidence: " + attr(b, "name")))
            self.solve_phase()
        # No stale expression facts from earlier rounds; fill nonexecuted syntax
        # without pretending it supplied evidence to binding/return summaries.
        for n in self.nodes:
            if isinstance(n, (ast.expr, ast.Slice)) and getattr(n, "_type", p.never) == p.never:
                if n in self.annotation_nodes:
                    n._type = p.unknown("annotation expression")  # type: ignore[attr-defined]
                else:
                    n._type = p.unknown("expression with no value evidence: " + type(n).__name__)  # type: ignore[attr-defined]
        for n in self.nodes:
            targets = self.function_targets(n) if isinstance(n, (ast.Name, ast.Lambda)) else []
            par = self.parent.get(n)
            if targets and not (isinstance(par, ast.Call) and par.func is n):
                for scope in targets:
                    self.functions[scope].escapes = True
        bindings = [{"id": attr(b, "id"), "declared": self.declared.get(attr(b, "id")),
                     "inferred": self.get(("b", attr(b, "id"), "")), "provenance": sorted(self.provenance[attr(b, "id")])} for b in self.table.bindings]
        functions: List[JSON] = []
        for f in self.functions.values():
            info = {"binding": f.binding, "scope": f.scope,
                    "params": [{"binding": bid(a), "declared": self.declared.get(bid(a)), "inferred": self.get(("p", bid(a), "")), "provenance": sorted(self.provenance[bid(a)] & {"callsites", "default", "method-receiver", "annotation"})} for a in f.params],
                    "ret_declared": f.ret_declared, "ret_inferred": self.get(("r", f.scope, "")), "escapes": f.escapes,
                    "is_generator": f.generator, "may_raise": bool(f.raises), "may_raise_reasons": sorted(f.raises)}
            if f.generator:
                info["yield_inferred"] = self.get(("y", f.scope, ""))
            functions.append(info)
        classes = []
        for cb in sorted(self.classes):
            fields = {key[2]: value for key, value in sorted(self.cells.items()) if key[0] == "f" and key[1] == cb}
            for (owner, name), b in sorted(self.class_attrs.items()):
                if owner == cb and (cb, name) not in self.methods:
                    fields[name] = p.join(fields.get(name, p.never), self.get(("b", b, "")))
            if cb in self.enum_classes:
                for (owner, name), _ in self.class_attrs.items():
                    if owner == cb and not name.startswith("_") and (cb, name) not in self.methods:
                        fields[name] = p.instance(self.classes[cb].name, binding=cb)
            escaped = self.get(("h", cb, ""))
            classes.append({"binding": cb, "fields": {name: p.join(t, escaped) for name, t in sorted(fields.items())}})
        stats = statistics(p.types, self.tree, bindings, functions)
        stats.update({"rounds": self.rounds, "iteration_limit_hit": self.limit_hit,
                      "limits": {"union": MAX_UNION, "depth": MAX_DEPTH, "tuple": MAX_TUPLE, "rounds_per_phase": MAX_ROUNDS}})
        return TypeFacts(p.types, bindings, functions, classes, stats)


def classification(types: Sequence[Mapping[str, Any]], t: int) -> Tuple[str, List[str]]:
    """Classify recursively: list[unknown] is not a known declaration type."""
    x = types[t]
    if x["k"] in ("unknown", "dynamic"):
        return x["k"], [x["why"]]
    children: List[int] = []
    for key in ("elem", "key", "value", "ret"):
        if key in x:
            children.append(x[key])
    for key in ("elems", "args", "params", "members"):
        children.extend(x.get(key, []))
    kinds: Set[str] = set()
    reasons: List[str] = []
    for child in children:
        kind, why = classification(types, child)
        kinds.add(kind)
        reasons.extend(why)
    return ("dynamic" if "dynamic" in kinds else "unknown" if "unknown" in kinds else "known"), sorted(set(reasons))


def annotation_expressions(tree: ast.Module) -> Set[ast.AST]:
    """Exclude expression syntax which describes types, not executed values."""
    nodes: Set[ast.AST] = set()
    for node in ast.walk(tree):
        positions: List[ast.AST] = []
        if isinstance(node, ast.AnnAssign):
            positions.append(node.annotation)
            if node.value is None:
                # A bare declaration has no value-producing assignment;
                # even its target is syntax, not a runtime value expression.
                positions.append(node.target)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            positions.extend(a.annotation for a in (list(node.args.posonlyargs) + list(node.args.args) +
                             list(node.args.kwonlyargs) +
                             ([node.args.vararg] if node.args.vararg else []) +
                             ([node.args.kwarg] if node.args.kwarg else [])) if a.annotation is not None)
            if getattr(node, "returns", None) is not None:
                positions.append(node.returns)
        if type(node).__name__ == "TypeAlias":
            positions.append(node.value)
        for part in positions:
            nodes.update(ast.walk(part))
    return nodes


def statistics(types: Sequence[Mapping[str, Any]], tree: ast.Module,
               bindings: List[JSON], functions: List[JSON]) -> JSON:
    excluded = annotation_expressions(tree)
    expressions = [n for n in ast.walk(tree) if isinstance(n, ast.expr) and n not in excluded]

    def categories(layer: str) -> Dict[str, List[int]]:
        expression_attr = {"inferred": "_type", "assumed": "_assumed", "represented": "_represented"}[layer]
        values = [getattr(n, expression_attr, getattr(n, "_type")) for n in expressions]
        if layer == "inferred":
            return {"expressions": values,
                    "bindings": [b["inferred"] for b in bindings],
                    "parameters": [a["inferred"] for f in functions for a in f["params"]],
                    "returns": [f["ret_inferred"] for f in functions]}
        return {"expressions": values,
                "bindings": [b.get(layer, b["inferred"]) for b in bindings],
                "parameters": [a.get(layer, a["inferred"]) for f in functions for a in f["params"]],
                "returns": [f.get("ret_" + layer, f["ret_inferred"]) for f in functions]}

    def count_layer(source: Dict[str, List[int]]) -> Tuple[JSON, JSON, JSON]:
        counts: JSON = {}
        unknown: collections.Counter[str] = collections.Counter()
        dynamic: collections.Counter[str] = collections.Counter()
        for name, ids in source.items():
            count = {"known": 0, "unknown": 0, "dynamic": 0}
            for t in ids:
                kind, reasons = classification(types, t)
                count[kind] += 1
                for reason in reasons:
                    (dynamic if kind == "dynamic" else unknown)[reason] += 1
            counts[name] = count
        return counts, dict(sorted(unknown.items())), dict(sorted(dynamic.items()))

    counts, unknown, dynamic = count_layer(categories("inferred"))
    assumed, a_unknown, a_dynamic = count_layer(categories("assumed"))
    represented, r_unknown, r_dynamic = count_layer(categories("represented"))
    return {"expressions": len(expressions), "unknown": counts["expressions"]["unknown"],
            "dynamic": counts["expressions"]["dynamic"], "unknown_reasons": unknown,
            "dynamic_reasons": dynamic, "categories": counts,
            "assumed_categories": assumed, "assumed_unknown_reasons": a_unknown,
            "assumed_dynamic_reasons": a_dynamic,
            "represented_categories": represented, "represented_unknown_reasons": r_unknown,
            "represented_dynamic_reasons": r_dynamic,
            "annotation_expressions_excluded": sum(isinstance(n, ast.expr) for n in excluded)}


def mark_api(tree: ast.Module, table: symbols.SymbolTable, raw: Analyzer,
             api: Optional[Sequence[Mapping[str, Any]]]) -> None:
    """Emitter metadata only for source-qualified imports or one nominal class.

    Use completed *assumed* expression types for receiver identification in
    every case, even when inferred and represented disagree. A union with None
    is permitted, but unions with two distinct classes are not.
    """
    if api is None:
        return
    pool = raw.p
    by_name = raw.api or {}
    def receiver_entry(node: ast.Attribute) -> Optional[JSON]:
        if (isinstance(node.value, ast.Name) and bid(node.value) is not None and
                (bid(node.value), node.attr) in raw.shadowed_member_bindings):
            return None
        type_id = getattr(node.value, "_assumed", None)
        if not isinstance(type_id, int):
            return None
        alternatives = [t for t in pool.members(type_id) if t != pool.none]
        if len(alternatives) != 1:
            return None
        obj = pool.types[alternatives[0]]
        if obj["k"] not in ("instance", "class") or obj.get("class_binding") is not None:
            return None
        return by_name.get(obj["name"] + "." + node.attr)
    def resolved(node: ast.AST) -> Optional[JSON]:
        if (isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) and
                bid(node.value) is not None and
                (bid(node.value), node.attr) in raw.shadowed_member_bindings):
            return None
        direct = raw.imported_api_name(node)
        if direct in by_name:
            return by_name[direct]
        if isinstance(node, ast.Attribute):
            return receiver_entry(node)
        return None
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Call, ast.Attribute, ast.Name)):
            continue
        entry: Optional[JSON]
        if isinstance(node, ast.Call):
            entry = resolved(node.func)
            if entry is not None and entry["kind"] in ("function", "constructor", "method", "class"):
                node._api = entry["python"]  # type: ignore[attr-defined]
        elif isinstance(node, ast.Attribute):
            entry = resolved(node)
            if entry is None:
                continue
            # A callee Attribute should not get an emitter marker separate
            # from its Call; a noncalled bound method can carry a marker.
            parent = raw.parent.get(node)
            if not (isinstance(parent, ast.Call) and parent.func is node):
                node._api = entry["python"]  # type: ignore[attr-defined]
        else:
            entry = resolved(node)
            if entry is not None and isinstance(node.ctx, ast.Load):
                node._api = entry["python"]  # type: ignore[attr-defined]


def run(tree: ast.Module, table: symbols.SymbolTable,
        externals: Optional[Mapping[str, JSON]] = None,
        module_name: Optional[str] = None, is_package: bool = False,
        api: Optional[Sequence[Mapping[str, Any]]] = None) -> TypeFacts:
    """Infer evidence, annotated assumptions, and declaration-first storage.

    ``api`` is a decoded runtime-library manifest; unlike a `.pyi` file it
    never imports or evaluates the named library. Representation is not proof
    of Python runtime type and is deliberately not checked by the oracle.
    """
    if not isinstance(tree, ast.Module):
        raise TypeError("infer.run requires ast.Module")
    for node in ast.walk(tree):
        for name in ("_assumed", "_represented", "_api"):
            if isinstance(node, (ast.expr, ast.Slice)) and hasattr(node, name):
                delattr(node, name)
    raw = Analyzer(tree, table, externals, module_name, is_package, api=api)
    facts = raw.finish()
    original = {node: getattr(node, "_type") for node in ast.walk(tree)
                if isinstance(node, (ast.expr, ast.Slice))}
    assumed = Analyzer(tree, table, externals, module_name, is_package, base=raw, api=api)
    assumed_facts = assumed.finish()
    assumptions = {node: getattr(node, "_type") for node in original}
    represented = Analyzer(tree, table, externals, module_name, is_package,
                           base=raw, declared_first=True, api=api)
    represented_facts = represented.finish()

    def copy(source: Analyzer, t: int) -> int:
        return intern_struct(raw.p, structural_type(source.p.types, t))

    for node, prior in original.items():
        node._represented = copy(represented, getattr(node, "_type"))  # type: ignore[attr-defined]
        node._assumed = copy(assumed, assumptions[node])  # type: ignore[attr-defined]
        node._type = prior  # type: ignore[attr-defined]

    for left, ai, ri in zip(facts.bindings, assumed_facts.bindings, represented_facts.bindings):
        left["assumed"] = copy(assumed, ai["inferred"])
        left["represented"] = copy(represented, ri["inferred"])
        if left["assumed"] != left["inferred"] or left["represented"] != left["inferred"]:
            left["provenance"] = sorted(set(left["provenance"]) | {"annotation"})
    for left, ai, ri in zip(facts.functions, assumed_facts.functions, represented_facts.functions):
        left["ret_assumed"] = copy(assumed, ai["ret_inferred"])
        left["ret_represented"] = copy(represented, ri["ret_inferred"])
        if left["ret_assumed"] != left["ret_inferred"] or left["ret_represented"] != left["ret_inferred"]:
            left["ret_provenance"] = ["annotation"]
        if "yield_inferred" in ai:
            left["yield_assumed"] = copy(assumed, ai["yield_inferred"])
        if "yield_inferred" in ri:
            left["yield_represented"] = copy(represented, ri["yield_inferred"])
        for lp, ap, rp in zip(left["params"], ai["params"], ri["params"]):
            lp["assumed"] = copy(assumed, ap["inferred"])
            lp["represented"] = copy(represented, rp["inferred"])
            if lp["declared"] is not None and (lp["assumed"] != lp["inferred"] or lp["represented"] != lp["inferred"]):
                lp["provenance"] = sorted(set(lp["provenance"]) | {"annotation"})
    for left, ai, ri in zip(facts.classes, assumed_facts.classes, represented_facts.classes):
        left["fields_assumed"] = {name: copy(assumed, t) for name, t in ai["fields"].items()}
        left["fields_represented"] = {name: copy(represented, t) for name, t in ri["fields"].items()}
        left["fields_declared"] = {name: copy(assumed, t) for (cb, name), t in assumed.declared_fields.items()
                                   if cb == left["binding"]}
        for (cb, name), field_binding in assumed.class_attrs.items():
            if cb == left["binding"] and field_binding in assumed.declared:
                left["fields_declared"][name] = copy(assumed, assumed.declared[field_binding])
        for name, declared in left["fields_declared"].items():
            left["fields_assumed"].setdefault(name, declared)
            left["fields_represented"][name] = declared

    facts.types = raw.p.types
    mark_api(tree, table, raw, api)
    facts.stats = statistics(facts.types, tree, facts.bindings, facts.functions)
    facts.stats.update({"rounds": raw.rounds, "assumed_rounds": assumed.rounds,
                        "represented_rounds": represented.rounds,
                        "iteration_limit_hit": raw.limit_hit,
                        "assumed_iteration_limit_hit": assumed.limit_hit,
                        "represented_iteration_limit_hit": represented.limit_hit,
                        "limits": {"union": MAX_UNION, "depth": MAX_DEPTH,
                                   "tuple": MAX_TUPLE, "rounds_per_phase": MAX_ROUNDS}})
    tree._infer_facts = facts  # type: ignore[attr-defined]
    tree._infer_raw = raw  # type: ignore[attr-defined]
    tree._infer_assumed = assumed  # type: ignore[attr-defined]
    tree._infer_represented = represented  # type: ignore[attr-defined]
    return facts


def summarize(tree: ast.Module, table: symbols.SymbolTable,
              module_name: Optional[str] = None, is_package: bool = False) -> JSON:
    """Export structurally self-contained facts for imports into other files.

    Call ``run`` first to avoid a second analysis. A standalone call computes
    a local summary with no external dependency information.
    """
    facts: TypeFacts = getattr(tree, "_infer_facts", None)
    raw: Optional[Analyzer] = getattr(tree, "_infer_raw", None)
    if facts is None or raw is None:
        facts = run(tree, table, module_name=module_name, is_package=is_package)
        raw = getattr(tree, "_infer_raw")
    module = module_name if module_name is not None else raw.module_name
    names = {cb: n.name for cb, n in raw.classes.items()}
    def exported(t: Optional[int]) -> Optional[JSON]:
        return (structural_type(facts.types, t, module, names, export=True)
                if t is not None else None)
    functions_by_binding = {f["binding"]: f for f in facts.functions if f["binding"] is not None}
    classes_by_binding = {c["binding"]: c for c in facts.classes}
    def function_info(f: JSON, flavor: str = "function") -> JSON:
        fn = raw.functions[f["scope"]]
        data: JSON = {
            "params": [{"name": a.arg, "declared": exported(t["declared"]),
                        "inferred": exported(t["inferred"]), "assumed": exported(t["assumed"]),
                        "represented": exported(t["represented"])}
                       for a, t in zip(fn.params, f["params"])],
            "ret_declared": exported(f["ret_declared"]),
            "ret_inferred": exported(f["ret_inferred"]),
            "ret_assumed": exported(f["ret_assumed"]),
            "ret_represented": exported(f["ret_represented"]),
            "escapes": f["escapes"], "is_generator": f["is_generator"],
            "may_raise": f["may_raise"], "flavor": flavor,
        }
        return data
    result: JSON = {"schema": 1, "module": module,
                    "is_package": is_package or raw.is_package,
                    "functions": {}, "classes": {}, "variables": {}}
    for f in facts.functions:
        fn = raw.functions[f["scope"]]
        if fn.owner is not None or fn.binding is None:
            continue
        if attr(table.bindings[fn.binding], "scope") == 0:
            result["functions"][fn.name] = function_info(f, fn.flavor)
    for cb, cls in sorted(raw.classes.items()):
        if attr(table.bindings[cb], "scope") != 0:
            continue
        data = classes_by_binding.get(cb, {"fields": {}, "fields_assumed": {}, "fields_declared": {}})
        field_names = set(data["fields"]) | set(data["fields_assumed"]) | set(data["fields_declared"]) | set(data.get("fields_represented", {}))
        fields = {}
        for name in sorted(field_names):
            declared = data["fields_declared"].get(name)
            inferred = data["fields"].get(name, raw.p.never)
            assumed = data["fields_assumed"].get(name, inferred)
            represented = data["fields_represented"].get(name, declared if declared is not None else assumed)
            fields[name] = {"declared": exported(declared), "inferred": exported(inferred),
                            "assumed": exported(assumed), "represented": exported(represented)}
        methods = {}
        for (owner, name), scopes in sorted(raw.methods.items()):
            if owner == cb:
                matching = [f for f in facts.functions if f["scope"] in scopes]
                if matching:
                    methods[name] = function_info(matching[-1], raw.functions[matching[-1]["scope"]].flavor)
        result["classes"][cls.name] = {"fields": fields, "methods": methods,
                                        "enum": cb in raw.enum_classes,
                                        "bases": [raw.qname(b) or dotted(b) for b in cls.bases]}
    for b in table.bindings:
        ident = attr(b, "id")
        if attr(b, "scope") != 0 or ident in functions_by_binding or ident in classes_by_binding:
            continue
        if attr(b, "name") == "*":
            continue
        fact = facts.bindings[ident]
        result["variables"][attr(b, "name")] = {
            "declared": exported(fact["declared"]),
            "inferred": exported(fact["inferred"]),
            "assumed": exported(fact["assumed"]),
            "represented": exported(fact["represented"]),
        }
    return result


def self_test() -> int:
    """No snippets are executed. Assertions exercise symbols + this module.

    Queries: a name selects a module binding; f.x selects a local; return:f,
    param:f.x and declared:x select summaries; expr:N checks the RHS at line N.
    """
    cases: List[Tuple[str, Dict[str, str]]] = [
        ("x=1", {"x": "int"}),
        ("x=1.0", {"x": "float"}),
        ("x=True", {"x": "bool"}),
        ("x=None", {"x": "none"}),
        ("x='abc'", {"x": "str"}),
        ("x=b'abc'", {"x": "bytes"}),
        ("x: float=1", {"x": "int", "declared:x": "float"}),
        ("x=1\nx=2.0", {"x": "union[int, float]"}),
        ("x=True\nx=1", {"x": "union[bool, int]"}),
        ("x=[]", {"x": "list[never]"}),
        ("x=[1,'a']", {"x": "list[union[int, str]]"}),
        ("x=[]\nx.append(1)", {"x": "list[int]"}),
        ("x=[]\nx.extend((1,2))", {"x": "list[int]"}),
        ("x=[]\nx.insert(0,'a')", {"x": "list[str]"}),
        ("x=[]\nx += [1]", {"x": "list[int]"}),
        ("x=[0]\nx[0]='a'", {"x": "list[union[int, str]]"}),
        ("x=[]\nx[:]=['a']", {"x": "list[str]"}),
        ("x=[]\ny=x\ny.append(1)", {"x": "list[int]", "y": "list[int]"}),
        ("x=[]\ndef f():\n x.append(1)\nf()", {"x": "list[int]"}),
        ("def f(xs):\n xs.append(1)\nx=[]\nf(x)", {"x": "list[int]"}),
        ("x={}\nx['a']=1", {"x": "dict[str, int]"}),
        ("x={}\nx.setdefault('a',1)", {"x": "dict[str, int]"}),
        ("x={}\nx.update({'a':1})", {"x": "dict[str, int]"}),
        ("x={}\nx.update(a=1)", {"x": "dict[str, int]"}),
        ("x={}\nx.update([('a',1)])", {"x": "dict[str, int]"}),
        ("d={'a':1}\nx=dict(**d)", {"x": "dict[str, int]"}),
        ("x=set()\nx.add(1)", {"x": "set[int]"}),
        ("x=set()\nx.update([1])", {"x": "set[int]"}),
        ("x=(1,'a')", {"x": "tuple[int, str]"}),
        ("a,b=(1,'a')", {"a": "int", "b": "str"}),
        ("a,*b,c=(1,'a',2.0,False)", {"a": "int", "b": "list[union[float, str]]", "c": "bool"}),
        ("x=(1,'a')[-1]", {"x": "str"}),
        ("x=(1,'a',True)[1:]", {"x": "tuple[str, bool]"}),
        ("x=(1,)+('a',)", {"x": "tuple[int, str]"}),
        ("x=b'ab'[0]\ny=b'ab'[:1]", {"x": "int", "y": "bytes"}),
        ("x='abc'[0]\ny=[1][0]", {"x": "str", "y": "int"}),
        ("x=2/1", {"x": "float"}),
        ("x=2.0//1", {"x": "float"}),
        ("x=2**-1", {"x": "float"}),
        ("x=2**3", {"x": "int"}),
        ("x=True+False", {"x": "int"}),
        ("x=True&False", {"x": "bool"}),
        ("x=-1\ny=not x", {"x": "int", "y": "bool"}),
        ("x=1<2", {"x": "bool"}),
        ("x=0 or 'a'", {"x": "str"}),
        ("x=1 and 'a'", {"x": "str"}),
        ("x=1 if True else 'a'", {"x": "int"}),
        ("x=f'{1}'", {"x": "str"}),
        ("for k,v in {'a':1}.items():\n x=(k,v)", {"x": "tuple[str, int]"}),
        ("for i,v in enumerate(['a']):\n x=(i,v)", {"x": "tuple[int, str]"}),
        ("for a,b in zip([1],['a']):\n x=(a,b)", {"x": "tuple[int, str]"}),
        ("x=[i+1 for i in range(3)]", {"x": "list[int]"}),
        ("x={i for i in range(3)}", {"x": "set[int]"}),
        ("x={str(i):i for i in range(3)}", {"x": "dict[str, int]"}),
        ("x=list(i for i in range(3))", {"x": "list[int]"}),
        ("def f(x):\n return x+1\ny=f(1)", {"param:f.x": "int", "return:f": "int", "y": "int"}),
        ("def f(x):\n x='a'\n return x\ny=f(1)", {"param:f.x": "int", "f.x": "union[int, str]", "return:f": "str"}),
        ("def f(x=1):\n return x\ny=f()", {"return:f": "int"}),
        ("def f(a,*,b):\n return (a,b)\nx=f(b='a',a=1)", {"x": "tuple[int, str]"}),
        ("def f(a,b):\n return (a,b)\nx=f(*(1,'a'))", {"x": "tuple[int, str]"}),
        ("def f(a,b):\n return (a,b)\nx=f(**{'a':1,'b':'a'})", {"x": "tuple[int, str]"}),
        ("def f(*a):\n return a\nx=f(1,2)", {"x": "tuple[int, int]"}),
        ("f=lambda x:x+1\ny=f(1)", {"y": "int"}),
        ("def f(x):\n if x:\n  return 1\nf(True)", {"return:f": "union[none, int]"}),
        ("def f():\n raise ValueError()", {"return:f": "never"}),
        ("def f():\n while True:\n  break", {"return:f": "none"}),
        ("def f():\n while True:\n  pass", {"return:f": "never"}),
        ("def f():\n try:\n  return 1\n finally:\n  return 'a'", {"return:f": "str"}),
        ("def fact(n):\n if n==0:\n  return 1\n return n*fact(n-1)\nx=fact(4)", {"return:fact": "int", "x": "int"}),
        ("def f(n):\n if n==0:\n  return True\n return g(n-1)\ndef g(n):\n return f(n)\nx=f(3)", {"return:f": "bool", "return:g": "bool"}),
        ("def f(x):\n if x is None:\n  return 0\n y=x\n return y\nf(None)\nf(1)", {"return:f": "int", "expr:4": "int"}),
        ("def f(x):\n if x is not None:\n  y=x\n  return y\n return 0\nf(None)\nf(1)", {"expr:3": "int"}),
        ("def f(x):\n if not x:\n  return 0\n y=x\n return y\nf(None)\nf(1)", {"expr:4": "int"}),
        ("def f(x):\n if isinstance(x,int):\n  y=x\n  return y+1\n return len(x)\nf(True)\nf(1)\nf('a')", {"expr:3": "union[bool, int]", "return:f": "int"}),
        ("class C:\n def __init__(self):\n  self.items=[]\n def add(self,x):\n  self.items.append(x)\nc=C()\nc.add(1)\nx=c.items", {"x": "list[int]"}),
        ("class C:\n x='a'\nx=C().x", {"x": "str"}),
        ("class C:\n def f(self,x):\n  return x\nx=C().f(1)", {"x": "int"}),
        ("x=' a '.strip().upper()\ny='a,b'.split(',')", {"x": "str", "y": "list[str]"}),
        ("x=[1].pop()", {"x": "int"}),
        ("x={'a':1}.get('b')", {"x": "union[none, int]"}),
        ("x=sorted([1])\ny=list(reversed(x))", {"x": "list[int]", "y": "list[int]"}),
        ("x=list(map(str,[1]))", {"x": "list[str]"}),
        ("x=list(filter(None,[1]))", {"x": "list[int]"}),
        ("x=sum([1,2])\ny=max([1,2])\nz=min(1,2)", {"x": "int", "y": "int", "z": "int"}),
        ("x=round(1.5)\ny=round(1.5,1)\nz=round(number=1.5)", {"x": "int", "y": "float", "z": "int"}),
        ("x=abs(-1)\ny=divmod(3,2)\nz=pow(2,-1,mod=3)", {"x": "int", "y": "tuple[int, int]", "z": "int"}),
        ("x=next(iter([1]),None)", {"x": "union[none, int]"}),
        ("x=any([1])\ny=all([1])\nz=isinstance(1,int)", {"x": "bool", "y": "bool", "z": "bool"}),
        ("x=ord('a')\ny=chr(65)\nz=hex(12)\nw=bin(2)", {"x": "int", "y": "str", "z": "str", "w": "str"}),
        ("x=print(1)\ny=input()\nz=repr(1)", {"x": "none", "y": "str", "z": "str"}),
        ("x=open('x')\ny=open('x','rb')", {"x": "io.TextIOBase", "y": "io.BufferedIOBase"}),
        ("class C:\n x=1\nc=C()\ny=getattr(c,'x')\nz=hasattr(c,'x')", {"y": "int", "z": "bool"}),
        ("x=type(1)\ny=type(None)", {"x": "type[int]", "y": "type[NoneType]"}),
        ("import os\nx=os.path.join('a','b')\ny=os.path.exists(x)\nz=os.environ.get('A')", {"x": "str", "y": "bool", "z": "union[none, str]"}),
        ("import json,time\nx=json.loads('{}')\ny=json.dumps({})\nz=time.time()", {"x": "dynamic[JSON value]", "y": "str", "z": "float"}),
        ("import re\nx=re.compile('a')\ny=re.sub('a','b','a')", {"x": "re.Pattern[str]", "y": "str"}),
        ("import datetime,pathlib,sqlite3\nx=datetime.datetime.now()\ny=pathlib.Path('x')\nz=sqlite3.connect(':memory:')", {"x": "datetime.datetime", "y": "pathlib.Path", "z": "sqlite3.Connection"}),
        ("from typing import Optional,Union,List,Dict,Tuple\nx:Optional[int]=None\ny:List[str]=[]\nz:Dict[str,int]={}\na:Tuple[int,...]=()", {"declared:x": "union[none, int]", "declared:y": "list[str]", "declared:z": "dict[str, int]", "declared:a": "tuple_of[int]"}),
        ("from typing import Final,ClassVar,Annotated,Literal,Any\na:Final[int]=1\nb:ClassVar[str]='a'\nc:Annotated[float,'tag']=1\nd:Literal[1,'a']=1\ne:Any=1", {"declared:a": "int", "declared:b": "str", "declared:c": "float", "declared:d": "union[int, str]", "declared:e": "dynamic[annotated Any]", "e": "int"}),
        ("from typing import Sequence,Iterable,Iterator,Mapping,Callable,Set\na:Sequence[int]=[]\nb:Iterable[str]=[]\nc:Iterator[int]=iter([])\nd:Mapping[str,int]={}\ne:Callable[[int],str]=None\nf:Set[int]=set()", {"declared:a": "collections.abc.Sequence[int]", "declared:b": "collections.abc.Iterable[str]", "declared:c": "collections.abc.Iterator[int]", "declared:d": "dict[str, int]", "declared:e": "Callable[[int], str]", "declared:f": "set[int]"}),
        ("from typing import TypeVar\nT=TypeVar('T')\nx:T=1", {"declared:x": "typevar[T]", "x": "int"}),
        ("class C:pass\nx:'C'=C()\ny:'int | None'=1", {"declared:x": "C", "declared:y": "union[none, int]"}),
        ("from typing import cast\nx=cast(float,1)", {"x": "float"}),
        ("def g():\n yield 1\n return 'done'\nx=list(g())", {"x": "list[int]", "return:g": "str"}),
        ("async def f():\n return 1\nasync def g():\n return await f()", {"return:f": "int", "return:g": "int"}),
    ]
    cases.extend([
        ("def f()->float:\n return 1", {"declared-return:f": "float", "return:f": "int"}),
        ("x=None\nassert True,(x:=1)\ny=x", {"y": "none"}),
        ("x=None\nclass C:\n global x\n x=1\ny=x", {"y": "int"}),
        ("x=None\ny=2<1<(x:=3)\nz=x", {"z": "union[none, int]"}),
        ("x=None\ny=(x:=1) if input() else (x:='a')\nz=x", {"z": "union[int, str]"}),
        ("x=None\ny=[(x:=i) for i in [1]]\nz=x", {"z": "union[none, int]"}),
        ("x=[]\ndef get():\n return x\ny=get()\ny.append(1)", {"x": "list[int]"}),
        ("x={1}.intersection({True})", {"x": "set[union[bool, int]]"}),
        ("x={1}\nx.intersection_update({True})", {"x": "set[union[bool, int]]"}),
        ("import math\nx=math.pi", {"x": "unknown[unknown module attribute: math.pi]"}),
        ("def f(x):\n if isinstance(x,list):\n  return x[0]\n return None\ny=f([1])", {"y": "int"}),
        ("def f(x):\n if isinstance(x,object):\n  return x\ny=f(1)", {"y": "int"}),
        ("import re\nx=re.match('a','a')\ny=re.search('a','a')\nz=re.findall('a','a')", {"x": "union[none, re.Match[str]]", "y": "union[none, re.Match[str]]", "z": "list[union[str, tuple_of[str]]]"}),
        ("def f(x=[]):\n x.append(1)\n return x\na=f()\nb=f()", {"param:f.x": "list[int]", "a": "list[int]", "b": "list[int]"}),
        ("x=[]\npush=x.append\npush(1)", {"x": "list[unknown[escaped bound mutator: append]]"}),
        ("class C:\n def __init__(self):\n  self.x=1\nc=C()\nsetattr(c,'x','a')\ny=c.x", {"y": "union[int, str]"}),
    ])
    cases.extend([
        ("x: float = 1", {"x": "int", "assumed:x": "int", "represented:x": "float"}),
        ("def f(x:int)->str:\n return x+1\ny=f(1)",
         {"return:f": "int", "assumed-return:f": "int", "represented-return:f": "str",
          "represented:y": "str", "y": "int", "represented-expr:3": "str"}),
        ("pairs=[(1,'a')]\nfor i,(a,b) in enumerate(pairs):\n t=(i,a,b)",
         {"i": "int", "a": "int", "b": "str", "t": "tuple[int, int, str]",
          "assumed:a": "int", "represented:b": "str"}),
        ("d={'a':1}\nfor k,v in d.items():\n pair=(k,v)",
         {"k": "str", "v": "int", "pair": "tuple[str, int]", "represented:pair": "tuple[str, int]"}),
        ("xs=[1,2,3]\na,*rest=xs", {"a": "int", "rest": "list[int]", "represented:rest": "list[int]"}),
        ("xs=[(1,'a'), (2,'b')]\n(a,b),*tail=xs",
         {"a": "int", "b": "str", "tail": "list[tuple[int, str]]"}),
        ("for i, (a,b) in enumerate([(1,'a')]):\n x=(i,a,b)",
         {"i": "int", "a": "int", "b": "str", "x": "tuple[int, int, str]"}),
        ("def f(pairs: list[tuple[int,str]]):\n for i,(a,b) in enumerate(pairs):\n  t=(i,a,b)",
         {"assumed:f.i": "int", "assumed:f.a": "int", "assumed:f.b": "str",
          "represented:f.i": "int", "represented:f.a": "int", "represented:f.b": "str"}),
        ("def f(d: dict[str,int]):\n for k,v in d.items():\n  t=(k,v)",
         {"assumed:f.k": "str", "assumed:f.v": "int",
          "represented:f.k": "str", "represented:f.v": "int"}),
        ("class Node:\n def __init__(self, value:int)->None:\n  self.value:int=value\n  self.next:Node|None=None\ndef f(head:Node|None)->int:\n if not head:\n  return -1\n node=head\n while node.next:\n  node=node.next\n return node.value",
         {"assumed:f.node": "Node", "represented:f.node": "Node",
          "assumed-use:9:node": "Node", "assumed-use:10:node": "Node",
          "represented-use:9:node": "Node", "represented-use:10:node": "Node",
          "assumed-attr:9:next": "union[none, Node]", "assumed-attr:10:next": "Node",
          "represented-attr:9:next": "union[none, Node]", "represented-attr:10:next": "Node"}),
        ("class Node:\n def __init__(self):\n  self.next:Node|None=None\ndef f(head:Node|None):\n node=head\n while node:\n  inside=node\n  node=node.next",
         {"assumed:f.inside": "Node", "represented:f.inside": "Node",
          "assumed-use:6:node": "union[none, Node]", "assumed-use:8:node": "Node",
          "represented-use:6:node": "union[none, Node]", "represented-use:8:node": "Node"}),
        ("class Node:\n def __init__(self):\n  self.next:Node|None=None\ndef f(head:Node|None):\n node=head\n while node is not None:\n  inside=node\n  node=node.next",
         {"assumed:f.inside": "Node", "represented:f.inside": "Node",
          "assumed-use:6:node": "union[none, Node]", "assumed-use:8:node": "Node",
          "represented-use:6:node": "union[none, Node]", "represented-use:8:node": "Node"}),
        ("class C:\n def __init__(self):\n  self.value:float=1\nc=C()\ny=c.value",
         {"y": "int", "assumed:y": "int", "represented:y": "float"}),
    ])
    failures = 0
    for number, (source, expected) in enumerate(cases, 1):
        try:
            tree = ast.parse(source)
            table = symbols.analyze(tree)
            facts = run(tree, table)
            actual: Dict[str, str] = {}
            for b in table.bindings:
                scope = table.scopes[attr(b, "scope")]
                name = attr(b, "name")
                label = name if attr(scope, "kind") == "module" else attr(scope, "name") + "." + name
                info = facts.bindings[attr(b, "id")]
                actual[label] = render_type(facts.types, info["inferred"])
                actual["assumed:" + label] = render_type(facts.types, info["assumed"])
                actual["represented:" + label] = render_type(facts.types, info["represented"])
                if info["declared"] is not None:
                    actual["declared:" + label] = render_type(facts.types, info["declared"])
            for f in facts.functions:
                name = attr(table.scopes[f["scope"]], "name")
                actual["return:" + name] = render_type(facts.types, f["ret_inferred"])
                actual["assumed-return:" + name] = render_type(facts.types, f["ret_assumed"])
                actual["represented-return:" + name] = render_type(facts.types, f["ret_represented"])
                if f["ret_declared"] is not None:
                    actual["declared-return:" + name] = render_type(facts.types, f["ret_declared"])
                for a in f["params"]:
                    label = name + "." + attr(table.bindings[a["binding"]], "name")
                    actual["param:" + label] = render_type(facts.types, a["inferred"])
                    actual["assumed-param:" + label] = render_type(facts.types, a["assumed"])
                    actual["represented-param:" + label] = render_type(facts.types, a["represented"])
            for n in ast.walk(tree):
                if isinstance(n, (ast.Assign, ast.AnnAssign)) and n.value is not None:
                    actual["expr:" + str(n.lineno)] = render_type(facts.types, n.value._type)
                    actual["assumed-expr:" + str(n.lineno)] = render_type(facts.types, n.value._assumed)
                    actual["represented-expr:" + str(n.lineno)] = render_type(facts.types, n.value._represented)
                if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load):
                    for layer, field_name in (("inferred", "_type"), ("assumed", "_assumed"), ("represented", "_represented")):
                        actual[layer + "-use:" + str(n.lineno) + ":" + n.id] = render_type(facts.types, getattr(n, field_name))
                if isinstance(n, ast.Attribute) and isinstance(n.ctx, ast.Load):
                    for layer, field_name in (("inferred", "_type"), ("assumed", "_assumed"), ("represented", "_represented")):
                        actual[layer + "-attr:" + str(n.lineno) + ":" + n.attr] = render_type(facts.types, getattr(n, field_name))
            for query, wanted in expected.items():
                if actual.get(query) != wanted:
                    raise AssertionError(query + ": expected " + wanted + ", got " + str(actual.get(query)))
        except Exception as exc:
            failures += 1
            print("self-test {}: {}\n{}".format(number, exc, source), file=sys.stderr)
    # Manifest regressions are separate to keep the original string-only
    # self-test vector schema backward compatible.
    manifest = [
        {"python": "sqlite3.connect", "kind": "function", "returns": "sqlite3.Connection", "params": [{"name": "database", "type": "str"}], "raises": True},
        {"python": "sqlite3.Connection.execute", "kind": "method", "receiver": "sqlite3.Connection", "returns": "sqlite3.Cursor", "params": [{"name": "sql", "type": "str"}, {"name": "parameters", "type": "Sequence[Any] | Mapping[str, Any]", "default": "()"}], "raises": True},
        {"python": "pathlib.Path", "kind": "constructor", "returns": "pathlib.Path"},
        {"python": "pathlib.Path.parent", "kind": "property", "returns": "pathlib.Path"},
        {"python": "datetime.datetime", "kind": "class", "returns": "datetime.datetime"},
        {"python": "datetime.datetime.now", "kind": "function", "returns": "datetime.datetime"},
        {"python": "datetime.timedelta", "kind": "constructor", "returns": "datetime.timedelta"},
        {"python": "datetime.timezone", "kind": "class", "returns": "datetime.timezone"},
        {"python": "datetime.timezone.utc", "kind": "constant", "returns": "datetime.timezone"},
        {"python": "testlib.value", "kind": "function", "returns": "list[Any]"},
    ]
    manifest_cases = [
        ("import sqlite3 as sq\nc=sq.connect('x')\nx=c.execute('sql')",
         {"x": "sqlite3.Cursor", "c": "sqlite3.Connection"},
         {"sq.connect('x')": "sqlite3.connect", "c.execute('sql')": "sqlite3.Connection.execute"}),
        ("from sqlite3 import connect as mk\nc=mk('x')\nx=c.execute('sql')",
         {"x": "sqlite3.Cursor"}, {"mk('x')": "sqlite3.connect", "c.execute('sql')": "sqlite3.Connection.execute"}),
        ("from pathlib import Path\np=Path('a')\nx=p.parent",
         {"x": "pathlib.Path"}, {"Path('a')": "pathlib.Path", "p.parent": "pathlib.Path.parent"}),
        ("from datetime import datetime, timedelta as td, timezone\na=datetime.now()\nb=td(days=1)\nc=timezone.utc",
         {"a": "datetime.datetime", "b": "datetime.timedelta", "c": "datetime.timezone"},
         {"datetime.now()": "datetime.datetime.now", "td(days=1)": "datetime.timedelta", "timezone.utc": "datetime.timezone.utc"}),
        ("import datetime as dt\na=dt.datetime.now()",
         {"a": "datetime.datetime"}, {"dt.datetime.now()": "datetime.datetime.now"}),
        ("from testlib import value as v\nx=v()",
         {"x": "list[dynamic[library value: testlib.value]]"}, {"v()": "testlib.value"}),
        ("import sqlite3 as sq\na=sq.connect('x')\nx=a if input() else None\ny=x.execute('sql')",
         {"y": "sqlite3.Cursor"}, {"x.execute('sql')": "sqlite3.Connection.execute"}),
        ("import sqlite3 as sq\nsq=1\nx=sq.connect('x')",
         {}, {"sq.connect('x')": None}),
        ("class Connection:\n def execute(self): return 1\nc=Connection()\ny=c.execute()",
         {"y": "int"}, {"c.execute()": None}),
        ("import sqlite3 as sq\nfrom pathlib import Path\na=sq.connect('x')\nb=Path('y')\nx=a if input() else b\ny=x.execute('sql')",
         {}, {"x.execute('sql')": None}),
    ]
    for index, (source, expected_bindings, expected_markers) in enumerate(manifest_cases, len(cases) + 1):
        try:
            tree = ast.parse(source)
            table = symbols.analyze(tree)
            facts = run(tree, table, api=manifest)
            actual = {attr(b, "name"): render_type(facts.types, facts.bindings[attr(b, "id")]["assumed"])
                      for b in table.bindings if attr(b, "scope") == 0}
            for name, expected in expected_bindings.items():
                if actual.get(name) != expected:
                    raise AssertionError(name + ": expected " + expected + ", got " + str(actual.get(name)))
            for code, expected in expected_markers.items():
                matches = [n for n in ast.walk(tree) if isinstance(n, (ast.Call, ast.Attribute))
                           and (ast.unparse(n) if hasattr(ast, "unparse")
                                else ast.get_source_segment(source, n)) == code]
                if len(matches) != 1 or getattr(matches[0], "_api", None) != expected:
                    raise AssertionError(code + ": expected _api " + str(expected) + ", got " +
                                         str([getattr(n, "_api", None) for n in matches]))
            # Every third-layer id must be interned in the returned pool.
            for item in facts.bindings:
                assert 0 <= item["represented"] < len(facts.types)
            for n in ast.walk(tree):
                if isinstance(n, ast.expr):
                    assert 0 <= n._represented < len(facts.types)
        except Exception as exc:
            failures += 1
            print("self-test {}: {}\n{}".format(index, exc, source), file=sys.stderr)
    print("self-test: {} snippets, {} failed".format(len(cases) + len(manifest_cases), failures))
    return 1 if failures else 0


def print_stats(label: str, stats: JSON, stream: Any) -> None:
    print(label + ":", file=stream)
    for layer, category_key, unknown_key, dynamic_key in (
        ("inferred", "categories", "unknown_reasons", "dynamic_reasons"),
        ("assumed", "assumed_categories", "assumed_unknown_reasons", "assumed_dynamic_reasons"),
        ("represented", "represented_categories", "represented_unknown_reasons", "represented_dynamic_reasons"),
    ):
        print("  " + layer + ":", file=stream)
        for category, counts in stats.get(category_key, {}).items():
            print("    {}: known={} unknown={} dynamic={}".format(
                category, counts["known"], counts["unknown"], counts["dynamic"]), file=stream)
        reasons: collections.Counter[str] = collections.Counter()
        for key in (unknown_key, dynamic_key):
            for reason, count in stats.get(key, {}).items():
                reasons[reason.split(":", 1)[0]] += count
        for reason, count in sorted(reasons.items(), key=lambda pair: (-pair[1], pair[0])):
            print("    {:6d}  {}".format(count, reason), file=stream)
    if "annotation_expressions_excluded" in stats:
        print("  annotation expressions excluded: " + str(stats["annotation_expressions_excluded"]), file=stream)


def empty_totals() -> JSON:
    return {key: {k: {c: 0 for c in ("known", "unknown", "dynamic")}
                  for k in ("expressions", "bindings", "parameters", "returns")}
            for key in ("categories", "assumed_categories", "represented_categories")} | {
                k: {} for k in ("unknown_reasons", "dynamic_reasons", "assumed_unknown_reasons", "assumed_dynamic_reasons", "represented_unknown_reasons", "represented_dynamic_reasons")}


def add_stats(total: JSON, stats: JSON) -> None:
    for layer in ("categories", "assumed_categories", "represented_categories"):
        for category, counts in stats[layer].items():
            for name, count in counts.items():
                total[layer][category][name] += count
    for group in ("unknown_reasons", "dynamic_reasons", "assumed_unknown_reasons", "assumed_dynamic_reasons", "represented_unknown_reasons", "represented_dynamic_reasons"):
        for reason, count in stats[group].items():
            total[group][reason] = total[group].get(reason, 0) + count
    total["annotation_expressions_excluded"] = (total.get("annotation_expressions_excluded", 0)
                                                 + stats.get("annotation_expressions_excluded", 0))


def _project_module(root: Path, path: Path) -> Tuple[str, bool]:
    relative = path.relative_to(root).with_suffix("")
    parts = list(relative.parts)
    is_package = parts[-1] == "__init__"
    if is_package:
        parts.pop()
    # A supplied root which is itself a package must prefix its children.
    if (root / "__init__.py").is_file():
        parts.insert(0, root.name)
    if not parts:
        parts = [root.name]
    return ".".join(parts), is_package


def project(root: str, show_stats: bool = False, show_json: bool = False,
            stream: Any = sys.stdout,
            api: Optional[Sequence[Mapping[str, Any]]] = None) -> int:
    """Bounded three-round module-summary propagation, using no source imports."""
    directory = Path(root).resolve()
    if not directory.is_dir():
        print("project root is not a directory: " + root, file=sys.stderr)
        return 1
    files = sorted((p for p in directory.rglob("*.py") if p.is_file() and not p.is_symlink()
                    and not any(part in ("__pycache__", ".venv", "venv", ".git") for part in p.relative_to(directory).parts)),
                   key=lambda p: p.as_posix())
    parsed: List[Tuple[Path, str, bool, ast.Module, symbols.SymbolTable]] = []
    failed = 0
    for path in files:
        try:
            with tokenize.open(str(path)) as handle:
                tree = ast.parse(handle.read(), filename=str(path))
            table = symbols.analyze(tree)
            module_name, package = _project_module(directory, path)
            parsed.append((path, module_name, package, tree, table))
        except Exception as exc:
            failed += 1
            print("{}: error {}: {}".format(path, type(exc).__name__, exc), file=sys.stderr)
    summaries: Dict[str, JSON] = {}
    final_facts: Dict[str, TypeFacts] = {}
    rounds = 0
    for index in range(3):
        rounds = index + 1
        upcoming: Dict[str, JSON] = {}
        for path, name, package, tree, table in parsed:
            try:
                facts = run(tree, table, externals=summaries, module_name=name, is_package=package, api=api)
                final_facts[str(path)] = facts
                upcoming[name] = summarize(tree, table, module_name=name, is_package=package)
            except Exception as exc:
                failed += 1
                print("{}: analysis error {}: {}".format(path, type(exc).__name__, exc), file=sys.stderr)
        if json.dumps(upcoming, sort_keys=True) == json.dumps(summaries, sort_keys=True):
            summaries = upcoming
            break
        summaries = upcoming
    totals = empty_totals()
    for path, name, _, _, _ in parsed:
        facts = final_facts.get(str(path))
        if facts is None:
            continue
        add_stats(totals, facts.stats)
        if show_stats:
            print_stats(str(path), facts.stats, stream)
        if show_json:
            print(json.dumps({"module": name, "summary": summaries.get(name),
                              "facts": facts.to_json()}, sort_keys=True, separators=(",", ":")), file=stream)
    if show_stats or not show_json:
        print_stats("TOTAL", totals, stream)
    print("project: {} files analyzed, {} summary rounds, {} errors".format(
        len(final_facts), rounds, failed), file=(sys.stderr if show_json else stream))
    return 1 if failed else 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*")
    parser.add_argument("--json", action="store_true", help="JSON Lines: one {file,facts} object per file")
    parser.add_argument("--stats", action="store_true")
    parser.add_argument("--explain", metavar="NAME")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--project", metavar="ROOT", help="analyze all Python files, propagating summaries for at most 3 rounds")
    parser.add_argument("--api", metavar="MANIFEST.json", help="passive JSON list of runtime-library signatures")
    parser.add_argument("--module-name", help="absolute dotted module name for a single file")
    parser.add_argument("--package", action="store_true", help="single FILE is a package initializer")
    options = parser.parse_args(argv)
    library_api: Optional[List[JSON]] = None
    if options.api:
        try:
            with open(options.api, "r", encoding="utf-8") as handle:
                parsed_api = json.load(handle)
            if not isinstance(parsed_api, list) or not all(isinstance(e, dict) for e in parsed_api):
                raise ValueError("manifest must be a JSON list of entry objects")
            library_api = parsed_api
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            parser.error("invalid --api manifest: " + str(exc))
    if options.self_test:
        return self_test()
    if options.project:
        if options.files:
            parser.error("FILE... and --project are mutually exclusive")
        return project(options.project, options.stats, options.json, api=library_api)
    if not options.files:
        parser.error("provide FILE..., --project ROOT, or --self-test")
    total = empty_totals()
    failed = False
    stream = sys.stderr if options.json else sys.stdout
    for filename in options.files:
        try:
            with tokenize.open(filename) as handle:
                source = handle.read()
            tree = ast.parse(source, filename=filename)
            table = symbols.analyze(tree)
            facts = run(tree, table, module_name=options.module_name, is_package=options.package, api=library_api)
            if options.json:
                print(json.dumps({"file": filename, "facts": facts.to_json()}, sort_keys=True, separators=(",", ":")))
            if options.stats or not (options.json or options.explain):
                print_stats(filename, facts.stats, stream)
            if options.explain:
                for b in table.bindings:
                    if attr(b, "name") != options.explain:
                        continue
                    info = facts.bindings[attr(b, "id")]
                    declared = "-" if info["declared"] is None else render_type(facts.types, info["declared"])
                    print("{}: binding {} scope {} {}\n  sites={}\n  declared={}\n  inferred={}\n  assumed={}\n  represented={}\n  provenance={}".format(
                        filename, attr(b, "id"), attr(b, "scope"), attr(b, "name"),
                        attr(b, "sites"), declared, render_type(facts.types, info["inferred"]),
                        render_type(facts.types, info["assumed"]),
                        render_type(facts.types, info["represented"]), ", ".join(info["provenance"])), file=stream)
            add_stats(total, facts.stats)
        except Exception as exc:
            failed = True
            print("{}: error: {}: {}".format(filename, type(exc).__name__, exc), file=sys.stderr)
    if options.stats:
        print_stats("TOTAL", total, stream)
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
