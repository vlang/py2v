"""Choose shared list descriptors only where identity can affect an observable result.

The graph is flow insensitive: assignments, local calls, returns, fields, and container
slots unify representations. A list needs a descriptor when it is both shared and mutated,
or when identity is compared. Fresh results and read-only aliases stay native. Unknown
escapes and operations this lowering cannot preserve are diagnosed, never copied silently.
"""
import ast
from collections import defaultdict, deque
from typing import Any, Dict, Iterable, Iterator, Optional, Set, Tuple


class UnsupportedListIdentity(Exception):
    """A shared-list operation for which this lowering cannot preserve Python semantics."""

    def __init__(self, reason: str, planner: 'Plan', node: Optional[ast.AST] = None,
                 keys: Iterable[Tuple[Any, ...]] = ()) -> None:
        super().__init__(reason)
        self.planner = planner
        self.node = node
        self.keys = set(keys)


class Plan:
    def __init__(self, tree, table, facts):
        self.tree, self.table, self.facts = tree, table, facts
        self.parent = {}
        self.types = defaultdict(set)
        self.children = {}
        self.shared, self.mutated, self.identity = set(), set(), set()
        self.dynamic = set()
        self.nodes, self.functions, self.classes, self.methods = {}, {}, {}, {}
        self.binding_types = {b['id']: b.get('assumed', b['inferred']) for b in facts.bindings}
        self.func_facts = {f['binding']: f for f in facts.functions}
        self.returns = {}
        self.bad_calls = []
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                self.classes[getattr(node, '_binding', None)] = node
                for fn in node.body:
                    if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        self.methods[(node.name, fn.name)] = fn
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                self.functions[getattr(node, '_binding', None)] = node
        self.parents = {id(c): n for n in ast.walk(tree) for c in ast.iter_child_nodes(n)}
        self.node_objects = {id(n): n for n in ast.walk(tree)}

    def walk(self, root: Optional[ast.AST] = None) -> Iterator[ast.AST]:
        """Keep refused signatures in the graph, excluding their discarded bodies."""
        pending = deque([self.tree if root is None else root])
        while pending:
            node = pending.popleft()
            refused = getattr(node, '_list_identity_error', '')
            if refused and not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
                continue
            yield node
            for field, value in ast.iter_fields(node):
                if field == 'body' and getattr(node, '_list_identity_error', ''):
                    continue
                if isinstance(value, list):
                    pending.extend(child for child in value if isinstance(child, ast.AST))
                elif isinstance(value, ast.AST):
                    pending.append(value)

    def unsupported(self, reason: str, node: Optional[ast.AST] = None,
                    keys: Iterable[Tuple[Any, ...]] = ()) -> UnsupportedListIdentity:
        groups = {self.find(key) for key in keys}
        if node is not None and not groups:
            groups.update(self.find(self.nodes[id(child)]) for child in ast.walk(node)
                          if id(child) in self.nodes and self.ref(child))
        return UnsupportedListIdentity(reason, self, node, groups)

    def refusal_scopes(self, error: UnsupportedListIdentity) -> Tuple[Dict[int, str], Set[int]]:
        """Find every owner of a failed alias group, including enclosing containers."""
        groups = {self.find(key) for key in error.keys}
        while True:
            parents = {key for key, child in self.slots.items() if child in groups}
            if parents <= groups:
                break
            groups.update(parents)
        touches = [self.node_objects[nid] for nid, key in self.nodes.items()
                   if self.find(key) in groups]
        touches.extend(self.node_objects[nid] for nid, key in self.returns.items()
                       if self.find(key) in groups)
        if error.node is not None:
            touches.append(error.node)
        owners = {}
        for node in touches:
            parent = self.parents.get(id(node))
            if isinstance(parent, ast.AnnAssign) and parent.value is None and parent.target is node:
                # A field annotation does not create or access a list object.
                continue
            current = node
            statement = None
            evaluated_owners = set()
            module_definition = None
            while current is not self.tree:
                parent = self.parents.get(id(current))
                if isinstance(parent, ast.arguments) and (
                        current in parent.defaults or current in parent.kw_defaults):
                    evaluated_owners.add(id(self.parents[id(parent)]))
                elif isinstance(parent, (ast.FunctionDef, ast.AsyncFunctionDef)) and (
                        current in parent.decorator_list or current is parent.returns):
                    evaluated_owners.add(id(parent))
                if isinstance(current, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)) \
                        and id(current) not in evaluated_owners:
                    break
                if isinstance(current, ast.stmt):
                    statement = current
                if parent is self.tree:
                    current = statement if statement is not None else current
                    if isinstance(current, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        module_definition = current
                        current = current.args
                    break
                if parent is None:
                    raise RuntimeError('cannot isolate list identity refusal')
                current = parent
            if current is self.tree:
                raise RuntimeError('cannot isolate module list identity refusal')
            label = []
            ancestor = current
            while ancestor is not self.tree and ancestor is not None:
                if isinstance(ancestor, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    label.append(ancestor.name)
                elif isinstance(ancestor, ast.Lambda):
                    label.append(f'<lambda@{ancestor.lineno}>')
                ancestor = self.parents.get(id(ancestor))
            name = (f'<module@{module_definition.lineno}>' if module_definition is not None
                    else '.'.join(reversed(label)) or f'<module@{getattr(current, "lineno", 0)}>')
            owners[current._list_refusal_id] = name
        group_nodes = {self.node_objects[nid]._list_refusal_id for nid, key in self.nodes.items()
                       if self.find(key) in groups}
        group_nodes.update(self.node_objects[nid]._list_refusal_id for nid, key in self.returns.items()
                           if self.find(key) in groups)
        return owners, group_nodes

    def find(self, key):
        self.parent.setdefault(key, key)
        if self.parent[key] != key:
            self.parent[key] = self.find(self.parent[key])
        return self.parent[key]

    def union(self, a, b):
        a, b = self.find(a), self.find(b)
        if a == b:
            return False
        self.parent[b] = a
        return True

    def entry(self, node):
        tid = getattr(node, '_assumed', getattr(node, '_type', None))
        if isinstance(node, (ast.Name, ast.arg)):
            tid = self.binding_types.get(getattr(node, '_binding', None), tid)
        return self.facts.types[tid] if tid is not None else {}

    def cls(self, node):
        entry = self.entry(node)
        return entry.get('name', '') if entry.get('k') == 'instance' else ''

    def child(self, key):
        self.children.setdefault(key, ('element', key))
        return self.children[key]

    def key(self, node):
        if isinstance(node, (ast.Name, ast.arg)) and getattr(node, '_binding', None) is not None:
            bid = node._binding
            scope = self.table.scopes[self.table.bindings[bid].scope]
            key = ('field', scope.name, getattr(node, 'id', getattr(node, 'arg', ''))) \
                if scope.kind == 'class' else ('binding', bid)
        elif isinstance(node, ast.Attribute):
            key = ('field', self.cls(node.value), node.attr)
        elif isinstance(node, ast.Subscript) and not isinstance(node.slice, ast.Slice):
            key = self.child(self.key(node.value))
        else:
            key = ('expression', id(node))
        self.find(key)
        self.nodes[id(node)] = key
        entry = self.entry(node)
        tid = getattr(node, '_assumed', getattr(node, '_type', None))
        if isinstance(node, (ast.Name, ast.arg)):
            tid = self.binding_types.get(getattr(node, '_binding', None), tid)
        if tid is not None:
            self.seed(key, tid)
        if isinstance(node, ast.List):
            self.types[key].add('list')
        return key

    def seed(self, key, tid, seen=None):
        seen = set() if seen is None else seen
        if tid in seen:
            return
        entry = self.facts.types[tid]
        kind = entry['k']
        if kind in ('unknown', 'dynamic', 'never'):
            return
        if kind == 'union':
            for member in entry.get('members', []):
                self.seed(key, member, seen | {tid})
            return
        if kind in ('list', 'dict', 'tuple_of'):
            self.types[key].add(kind)
            elem = entry['value'] if kind == 'dict' else entry['elem']
            self.seed(self.child(key), elem, seen | {tid})
            if kind == 'dict':
                self.types[('dict-key', key)].add(self.facts.types[entry['key']]['k'])
        elif kind == 'tuple':
            self.types[key].add('tuple_of')
            for elem in entry.get('elems', []):
                self.seed(self.child(key), elem, seen | {tid})
        elif kind == 'instance':
            self.types[key].add(entry.get('name', 'Any'))
        else:
            self.types[key].add({'str': 'string', 'float': 'f64', 'none': 'Any'}.get(kind, kind))

    def homogeneous_slot(self, node):
        entry = self.entry(node)
        parent = self.parents.get(id(node))
        if isinstance(parent, (ast.Assign, ast.AnnAssign)) and parent.value is node:
            targets = parent.targets if isinstance(parent, ast.Assign) else [parent.target]
            for target in targets:
                target_entry = self.entry(target)
                element = target_entry.get('value') if target_entry.get('k') == 'dict' else target_entry.get('elem')
                if element is not None and self.facts.types[element]['k'] in ('union', 'dynamic', 'unknown'):
                    return False
        element = entry.get('value') if entry.get('k') == 'dict' else entry.get('elem')
        return element is not None and self.facts.types[element]['k'] not in ('union', 'dynamic', 'unknown')

    def local_call(self, node):
        if isinstance(node.func, ast.Name):
            binding = getattr(node.func, '_binding', None)
            if binding in self.classes:
                return self.methods.get((self.classes[binding].name, '__init__')), True
            return self.functions.get(binding) or self.functions.get(self.entry(node.func).get('func_binding')), False
        if isinstance(node.func, ast.Attribute):
            return self.methods.get((self.cls(node.func.value), node.func.attr)), True
        return None, False

    def random_member(self, node):
        member = getattr(node.func, '_math_member', '')
        if member.startswith('random.'):
            return member.split('.')[-1]
        if (isinstance(node.func, ast.Attribute)
                and self.entry(node.func.value).get('k') == 'module'
                and self.entry(node.func.value).get('name') == 'random'):
            return node.func.attr
        return ''

    def shuffle(self, node):
        return self.random_member(node) == 'shuffle'

    def own_function(self, node):
        parent = self.parents.get(id(node))
        while parent is not None:
            if isinstance(parent, (ast.FunctionDef, ast.AsyncFunctionDef)):
                return parent
            parent = self.parents.get(id(parent))
        return None

    def any_annotation(self, annotation):
        return isinstance(annotation, (ast.Name, ast.Attribute)) \
            and ast.unparse(annotation).split('.')[-1] == 'Any'

    def dynamic_escape(self, value):
        if not isinstance(value, (ast.List, ast.ListComp, ast.Dict, ast.Set, ast.Tuple, ast.Constant)):
            self.shared.add(self.key(value))
            self.mutated.add(self.key(value))

    def bind(self, target, value):
        if isinstance(target, (ast.Tuple, ast.List)):
            if isinstance(value, (ast.Tuple, ast.List)) and len(target.elts) == len(value.elts):
                for left, right in zip(target.elts, value.elts):
                    self.bind(left, right)
            else:
                for elt in target.elts:
                    if isinstance(elt, ast.Name):
                        self.union(self.key(elt), self.child(self.key(value)))
                        self.shared.add(self.key(elt))
            return
        if isinstance(target, ast.Subscript) and not self.homogeneous_slot(target.value):
            self.dynamic_escape(value)
            self.mutated.add(self.key(target.value))
            return
        if isinstance(target, (ast.Name, ast.Attribute, ast.Subscript)):
            self.union(self.key(target), self.key(value))
            if isinstance(value, (ast.Name, ast.Attribute, ast.Subscript, ast.IfExp)) \
                    and not (isinstance(value, ast.Subscript) and isinstance(value.slice, ast.Slice)):
                self.shared.add(self.key(value))
        if isinstance(target, ast.Subscript):
            self.mutated.add(self.key(target.value))

    def iterate(self, target, iterable):
        if isinstance(target, (ast.Tuple, ast.List)) and isinstance(iterable, ast.Call):
            func = iterable.func
            if isinstance(func, ast.Name) and func.id == 'enumerate' and len(target.elts) == 2:
                self.union(self.key(target.elts[1]), self.child(self.key(iterable.args[0])))
                self.shared.add(self.key(target.elts[1]))
                return
            if isinstance(func, ast.Name) and func.id == 'zip':
                for elt, value in zip(target.elts, iterable.args):
                    self.union(self.key(elt), self.child(self.key(value)))
                    self.shared.add(self.key(elt))
                return
            if isinstance(func, ast.Attribute) and func.attr == 'items' and len(target.elts) == 2:
                self.union(self.key(target.elts[1]), self.child(self.key(func.value)))
                self.shared.add(self.key(target.elts[1]))
                return
        self.union(self.key(target), self.child(self.key(iterable)))
        if self.entry(target).get('k') == 'list':
            self.shared.add(self.key(target))

    def graph(self):
        for node in ast.walk(self.tree):
            if isinstance(node, (ast.expr, ast.arg)):
                self.key(node)
                if isinstance(node, ast.arg) and getattr(node, '_binding', None) is not None:
                    if self.any_annotation(node.annotation):
                        self.dynamic.add(self.key(node))
                    if self.table.bindings[node._binding].rebound:
                        self.shared.add(self.key(node))
                if isinstance(node, ast.Name) and getattr(node, '_binding', None) is not None:
                    if self.table.bindings[node._binding].captured:
                        self.shared.add(self.key(node))
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                key = ('return', id(node))
                self.returns[id(node)] = key
                info = self.func_facts.get(getattr(node, '_binding', None), {})
                tid = info.get('ret_assumed', info.get('ret_inferred'))
                if tid is not None:
                    self.seed(key, tid)
            if isinstance(node, (ast.Assign, ast.AnnAssign, ast.NamedExpr)):
                value = node.value
                if value is None:
                    continue
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                if len(targets) > 1:
                    self.shared.add(self.key(value))
                for target in targets:
                    self.bind(target, value)
            elif isinstance(node, ast.AugAssign):
                if isinstance(node.target, ast.Subscript):
                    self.mutated.add(self.key(node.target.value))
                else:
                    self.mutated.add(self.key(node.target))
                if isinstance(node.op, (ast.Add, ast.Mult)):
                    self.mutated.add(self.key(node.target))
                if isinstance(node.op, ast.Add):
                    self.union(self.child(self.key(node.target)), self.child(self.key(node.value)))
            elif isinstance(node, ast.Return) and node.value is not None:
                fn = self.own_function(node)
                if fn is not None:
                    if self.any_annotation(fn.returns):
                        self.dynamic.add(('return', id(fn)))
                        self.dynamic_escape(node.value)
                        continue
                    key = ('return', id(fn))
                    self.union(key, self.key(node.value))
                    value = node.value
                    if isinstance(value, (ast.Attribute, ast.Subscript)) or (
                            isinstance(value, ast.Name) and getattr(value, '_binding', None) is not None
                            and (self.table.bindings[value._binding].is_param
                                 or self.table.bindings[value._binding].captured)):
                        self.shared.add(key)
            elif isinstance(node, (ast.List, ast.Tuple)):
                if isinstance(node.ctx, ast.Store):
                    continue
                key = self.key(node)
                parent = self.parents.get(id(node))
                if (isinstance(node, ast.Tuple) and isinstance(parent, ast.Assign)
                        and parent.value is node and len(parent.targets) == 1
                        and isinstance(parent.targets[0], (ast.Tuple, ast.List))):
                    continue
                for elt in node.elts:
                    if isinstance(elt, ast.Starred):
                        self.union(self.child(key), self.child(self.key(elt.value)))
                        self.shared.add(self.child(self.key(elt.value)))
                        continue
                    homogeneous = (self.homogeneous_slot(node) if isinstance(node, ast.List)
                                   else len({self.entry(e).get('k') for e in node.elts}) <= 1)
                    if homogeneous:
                        self.union(self.child(key), self.key(elt))
                    else:
                        self.mutated.add(self.key(elt))
                    if isinstance(elt, (ast.Name, ast.Attribute, ast.Subscript)):
                        self.shared.add(self.key(elt))
            elif isinstance(node, ast.Dict):
                for value in node.values:
                    if self.homogeneous_slot(node):
                        self.union(self.child(self.key(node)), self.key(value))
                    else:
                        self.mutated.add(self.key(value))
                    if isinstance(value, (ast.Name, ast.Attribute, ast.Subscript)):
                        self.shared.add(self.key(value))
            elif isinstance(node, ast.BinOp) and self.entry(node).get('k') == 'list':
                for operand in (node.left, node.right):
                    if self.entry(operand).get('k') == 'list':
                        self.union(self.child(self.key(node)), self.child(self.key(operand)))
                        self.shared.add(self.child(self.key(operand)))
            elif isinstance(node, ast.IfExp):
                self.union(self.key(node), self.key(node.body))
                self.union(self.key(node), self.key(node.orelse))
            elif isinstance(node, (ast.For, ast.comprehension)):
                self.iterate(node.target, node.iter)
            elif isinstance(node, ast.ListComp):
                self.union(self.child(self.key(node)), self.key(node.elt))
                if self.entry(node.elt).get('k') == 'list':
                    self.shared.add(self.key(node.elt))
            elif isinstance(node, ast.Delete):
                for target in node.targets:
                    if isinstance(target, ast.Subscript):
                        self.mutated.add(self.key(target.value))
            elif isinstance(node, ast.Compare) and any(isinstance(op, (ast.Is, ast.IsNot)) for op in node.ops):
                for op, left, right in zip(node.ops, [node.left] + node.comparators, node.comparators):
                    if isinstance(op, (ast.Is, ast.IsNot)) and not any(
                            isinstance(n, ast.Constant) and n.value is None for n in (left, right)):
                        self.identity.update((self.key(left), self.key(right)))
            elif isinstance(node, ast.Call):
                if self.shuffle(node) and node.args:
                    self.mutated.add(self.key(node.args[0]))
                    continue
                if self.random_member(node) in ('choice', 'choices', 'sample') and node.args:
                    child = self.child(self.key(node.args[0]))
                    if self.random_member(node) == 'choice':
                        self.union(self.key(node), child)
                    else:
                        self.union(self.child(self.key(node)), child)
                    self.shared.add(child)
                    continue
                fn, method = self.local_call(node)
                if fn is None and isinstance(node.func, ast.Name) \
                        and getattr(node.func, '_binding', None) in self.classes:
                    cls = self.classes[node.func._binding]
                    fields = [stmt.target for stmt in cls.body if isinstance(stmt, ast.AnnAssign)
                              and isinstance(stmt.target, ast.Name)]
                    for field, value in zip(fields, node.args):
                        self.bind(field, value)
                    by_name = {field.id: field for field in fields}
                    for kw in node.keywords:
                        if kw.arg in by_name:
                            self.bind(by_name[kw.arg], kw.value)
                    continue
                if fn is not None:
                    seen_args = set()
                    for value in node.args + [kw.value for kw in node.keywords]:
                        key = self.key(value)
                        if key in seen_args:
                            self.shared.add(key)
                        seen_args.add(key)
                    if self.any_annotation(fn.returns):
                        self.dynamic.add(self.key(node))
                    args = fn.args.posonlyargs + fn.args.args
                    if method:
                        args = args[1:]
                    for param, value in zip(args, node.args):
                        if self.any_annotation(param.annotation):
                            self.dynamic_escape(value)
                        else:
                            self.union(self.key(param), self.key(value))
                    by_name = {a.arg: a for a in args + fn.args.kwonlyargs}
                    for kw in node.keywords:
                        if kw.arg in by_name:
                            if self.any_annotation(by_name[kw.arg].annotation):
                                self.dynamic_escape(kw.value)
                            else:
                                self.union(self.key(by_name[kw.arg]), self.key(kw.value))
                    if not self.any_annotation(fn.returns) and not (isinstance(node.func, ast.Name) and getattr(node.func, '_binding', None) in self.classes):
                        self.union(self.key(node), ('return', id(fn)))
                elif isinstance(node.func, ast.Attribute):
                    receiver, name = node.func.value, node.func.attr
                    if name in ('append', 'extend', 'insert', 'pop', 'remove', 'clear', 'sort', 'reverse'):
                        self.mutated.add(self.key(receiver))
                    if name == 'append' and node.args:
                        if self.homogeneous_slot(receiver):
                            self.union(self.child(self.key(receiver)), self.key(node.args[0]))
                        else:
                            self.mutated.add(self.key(node.args[0]))
                        if isinstance(node.args[0], (ast.Name, ast.Attribute, ast.Subscript, ast.IfExp)):
                            self.shared.add(self.key(node.args[0]))
                    elif name == 'insert' and len(node.args) == 2:
                        if self.homogeneous_slot(receiver):
                            self.union(self.child(self.key(receiver)), self.key(node.args[1]))
                        else:
                            self.mutated.add(self.key(node.args[1]))
                        if isinstance(node.args[1], (ast.Name, ast.Attribute, ast.Subscript, ast.IfExp)):
                            self.shared.add(self.key(node.args[1]))
                    elif name == 'extend' and node.args:
                        self.union(self.child(self.key(receiver)), self.child(self.key(node.args[0])))
                        self.shared.add(self.child(self.key(node.args[0])))
                    elif name in ('pop', 'get', 'setdefault'):
                        self.union(self.key(node), self.child(self.key(receiver)))
                        self.shared.add(self.key(node))
                        if name in ('get', 'setdefault') and len(node.args) > 1:
                            self.union(self.key(node), self.key(node.args[1]))
                    elif name == 'copy':
                        self.union(self.child(self.key(node)), self.child(self.key(receiver)))
                        self.shared.add(self.child(self.key(receiver)))
                    elif name == 'values':
                        self.union(self.child(self.key(node)), self.child(self.key(receiver)))
                        self.shared.add(self.child(self.key(receiver)))
                    else:
                        self.bad_calls.append(node)
                elif isinstance(node.func, ast.Name) and node.func.id in (
                        'print', 'len', 'sum', 'min', 'max', 'sorted', 'reversed', 'enumerate', 'zip',
                        'list', 'tuple', 'set', 'frozenset', 'all', 'any', 'bool', 'str', 'repr', 'int', 'float', 'isinstance',
                        'map', 'filter'):
                    if node.func.id in ('list', 'sorted') and node.args:
                        self.union(self.child(self.key(node)), self.child(self.key(node.args[0])))
                        self.shared.add(self.child(self.key(node.args[0])))
                else:
                    self.bad_calls.append(node)
        # An opaque callee may keep or mutate an argument. Never pass a native descriptor
        # through such a boundary and assume the caller's original will stay unchanged.
        for call in self.bad_calls:
            if getattr(call, '_api', ''):
                continue
            # Frontend-created pyrt calls have defined boundaries, not opaque escapes.
            if (isinstance(call.func, ast.Attribute)
                    and isinstance(call.func.value, ast.Name)
                    and call.func.value.id == 'pyrt'
                    and getattr(call.func.value, '_binding', None) is None):
                continue
            if isinstance(call.func, ast.Attribute) and call.func.attr in (
                    'count', 'index', 'items', 'keys', 'values', 'join'):
                continue
            if isinstance(call.func, ast.Attribute) and call.func.attr == 'format' \
                    and self.entry(call.func.value).get('k') == 'str':
                continue
            for arg in call.args + [kw.value for kw in call.keywords]:
                self.dynamic_escape(arg)
        # A copied or sliced outer sequence retains its element objects.
        for node in ast.walk(self.tree):
            if isinstance(node, ast.Subscript) and isinstance(node.slice, ast.Slice):
                self.union(self.child(self.key(node)), self.child(self.key(node.value)))
                self.shared.add(self.child(self.key(node.value)))
        while True:
            groups = {}
            changed = False
            for parent, child in list(self.children.items()):
                root = self.find(parent)
                if root in groups:
                    changed |= self.union(child, groups[root])
                else:
                    groups[root] = child
            if not changed:
                break
        self.kinds = defaultdict(set)
        for key, kinds in self.types.items():
            self.kinds[self.find(key)].update(kinds)
        self.slots = {self.find(k): self.find(v) for k, v in self.children.items()}
        mutated = {self.find(k) for k in self.mutated}
        self.mutation_roots = mutated
        shared = {self.find(k) for k in self.shared}
        identity = {self.find(k) for k in self.identity}
        dynamic = {self.find(k) for k in self.dynamic}
        self.dynamic_roots = dynamic
        self.selected = {k for k, kinds in self.kinds.items()
                         if k not in dynamic and 'list' in kinds
                         and (k in identity or k in shared and k in mutated)}
        # Containers carrying a shared descriptor need a consistent element representation.
        while True:
            grown = {k for k, child in self.slots.items()
                     if child in self.selected and k not in dynamic and 'list' in self.kinds[k]} - self.selected
            if not grown:
                break
            self.selected |= grown
        # Retain the full graph for the unaffected groups, including facts from
        # discarded bodies. Only the explicitly refused groups lose descriptors.
        refused = {self.find(key) for nid, key in self.nodes.items()
                   if getattr(self.node_objects[nid], '_list_group_refused', False)}
        refused.update(self.find(key) for nid, key in self.returns.items()
                       if getattr(self.node_objects[nid], '_list_group_refused', False))
        self.selected -= refused
        return self

    def spelling(self, key, seen=None):
        key = self.find(key)
        seen = set() if seen is None else seen
        if key in seen:
            raise self.unsupported('py2v: recursive native list identity is not supported', keys=[key])
        kinds = self.kinds[key]
        if len(kinds) > 1 and key not in self.selected:
            return 'Any'
        if 'list' in kinds or 'dict' in kinds or 'tuple_of' in kinds:
            kind = 'list' if 'list' in kinds else 'dict' if 'dict' in kinds else 'tuple_of'
            elem = self.spelling(self.slots[key], seen | {key}) if key in self.slots else 'Any'
            if key in self.selected:
                if kinds != {'list'}:
                    raise self.unsupported('py2v: a shared list rebound to a different type is not supported', keys=[key])
                return f'&pyrt.ListRef[{elem}]'
            if kind == 'dict':
                keys = set()
                for original in self.parent:
                    if self.find(original) == key:
                        keys |= self.types.get(('dict-key', original), set())
                return f"map[{'int' if keys == {'int'} else 'string'}]{elem}"
            return '[]' + elem
        if len(kinds) == 1 and (next(iter(kinds)) in ('int', 'f64', 'string', 'bool', 'Any')
                or next(iter(kinds)) in {cls.name for cls in self.classes.values()}):
            return next(iter(kinds))
        return 'Any'

    def ref(self, node):
        key = self.nodes.get(id(node))
        return key is not None and self.find(key) in self.selected

    def changed_type(self, key):
        if self.find(key) in self.dynamic_roots:
            return ''
        try:
            result = self.spelling(key)
        except UnsupportedListIdentity:
            if self.find(key) in self.selected:
                raise
            return ''
        return result if 'pyrt.ListRef[' in result else ''

    def validate(self):
        resize = {'append', 'extend', 'insert', 'pop', 'remove', 'clear'}
        effects = defaultdict(set)
        calls = []

        def resize_targets(node):
            targets = []
            if isinstance(node, ast.Call):
                if isinstance(node.func, ast.Attribute) and node.func.attr in resize:
                    targets.append(node.func.value)
                elif self.shuffle(node) and node.args:
                    targets.append(node.args[0])
            elif isinstance(node, ast.AugAssign) and isinstance(node.op, (ast.Add, ast.Mult)):
                target = node.target
                targets.append(target.value if isinstance(target, ast.Subscript)
                               and isinstance(target.slice, ast.Slice) else target)
            elif isinstance(node, ast.Delete):
                targets.extend(t.value for t in node.targets if isinstance(t, ast.Subscript))
            elif isinstance(node, (ast.Assign, ast.AnnAssign)):
                assigned = node.targets if isinstance(node, ast.Assign) else [node.target]
                targets.extend(t.value for t in assigned if isinstance(t, ast.Subscript)
                               and isinstance(t.slice, ast.Slice))
            return targets

        def resize_roots(node):
            return {self.find(self.key(target)) for target in resize_targets(node)}

        assignments = defaultdict(list)
        for node in self.walk():
            if isinstance(node, (ast.Assign, ast.AnnAssign, ast.NamedExpr)) and node.value is not None:
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                for target in targets:
                    if isinstance(target, ast.Name):
                        assignments[getattr(target, '_binding', None)].append(node.value)

        def local_origin(node, seen=None):
            if not isinstance(node, (ast.Name, ast.arg)):
                return None
            bid = getattr(node, '_binding', None)
            seen = set() if seen is None else seen
            if bid is None or bid in seen:
                return None
            values = assignments[bid]
            owner = self.own_function(node)
            if not values and self.table.bindings[bid].is_param:
                return ('parameter', bid, id(owner))
            if len(values) != 1:
                return None
            value = values[0]
            if isinstance(value, (ast.List, ast.ListComp)):
                return ('fresh', id(value), id(self.own_function(value)))
            if isinstance(value, ast.Name):
                return local_origin(value, seen | {bid})
            return None

        def distinct_fresh(left, right):
            a, b = local_origin(left), local_origin(right)
            # Recursive calls unify representation types across frames. A fresh local
            # allocation cannot alias an unrebound parameter of its own invocation.
            return bool(a and b and a[2] == b[2] and a != b
                        and (a[0] == 'fresh' or b[0] == 'fresh'))

        for node in self.walk():
            fn = self.own_function(node)
            owner = id(fn) if fn is not None else None
            effects[owner].update(resize_roots(node))
            if isinstance(node, ast.Call):
                calls.append((owner, node))

        def call_effects(call):
            fn, method = self.local_call(call)
            if fn is None:
                return set()
            result = set(effects[id(fn)])
            params = fn.args.posonlyargs + fn.args.args
            if method:
                params = params[1:]
            actual = list(zip(params, call.args))
            named = {p.arg: p for p in params + fn.args.kwonlyargs}
            actual += [(named[k.arg], k.value) for k in call.keywords if k.arg in named]
            for param, value in actual:
                if self.find(self.key(param)) in result:
                    result.add(self.find(self.key(value)))
            return result

        while True:
            changed = False
            for owner, call in calls:
                before = len(effects[owner])
                effects[owner].update(call_effects(call))
                changed |= len(effects[owner]) != before
            if not changed:
                break

        def iteration_values(iterable):
            if self.ref(iterable) or self.entry(iterable).get('k') == 'list':
                return [iterable]
            if isinstance(iterable, ast.Call) and isinstance(iterable.func, ast.Name):
                name = iterable.func.id
                args = (iterable.args[:1] if name in ('enumerate', 'reversed') else
                        iterable.args if name == 'zip' else
                        iterable.args[1:] if name in ('map', 'filter') else [])
                return [value for arg in args for value in iteration_values(arg)]
            return []

        for node in self.walk():
            if isinstance(node, (ast.For, ast.comprehension)) and iteration_values(node.iter):
                iterated = iteration_values(node.iter)
                roots = {self.find(self.key(value)) for value in iterated}
                line = getattr(node, 'lineno', getattr(self.parents.get(id(node)), 'lineno', 0))
                if isinstance(node, ast.For):
                    body = node.body
                else:
                    parent = self.parents[id(node)]
                    body = ([part for part in (parent.key, parent.value) if part is not None]
                            if isinstance(parent, ast.DictComp) else [parent.elt])
                    body += [cond for gen in parent.generators for cond in gen.ifs]
                for stmt in body:
                    for call in self.walk(stmt):
                        if isinstance(call, ast.Call) and roots & call_effects(call):
                            raise self.unsupported(f'py2v:{line}: a call may resize or reorder '
                                             'the list during iteration; this is not supported', node, roots)
                        if any(self.find(self.key(target)) == self.find(self.key(value))
                               and not distinct_fresh(target, value)
                               for target in resize_targets(call) for value in iterated):
                            raise self.unsupported(f'py2v:{line}: resizing or reordering a shared list '
                                             'during iteration is not supported', node, roots)
        active = {id(node) for node in self.walk()}
        for call in self.bad_calls:
            if id(call) not in active:
                continue
            if getattr(call, '_api', ''):
                continue
            # Frontend-created pyrt calls have defined boundaries, not opaque escapes.
            if (isinstance(call.func, ast.Attribute)
                    and isinstance(call.func.value, ast.Name)
                    and call.func.value.id == 'pyrt'
                    and getattr(call.func.value, '_binding', None) is None):
                continue
            if isinstance(call.func, ast.Attribute) and call.func.attr in ('count', 'index', 'items', 'keys', 'values', 'join'):
                continue
            if self.ref(call):
                raise self.unsupported(f'py2v:{call.lineno}: shared list received from an unresolved call; '
                                       'cannot preserve native list identity at this boundary', call,
                                       [self.nodes[id(call)]])
            if any(self.ref(arg) for arg in call.args + [kw.value for kw in call.keywords]):
                raise self.unsupported(f'py2v:{call.lineno}: shared list passed to an unresolved call; '
                                 'cannot preserve native list identity at this boundary', call)
        return self

    def annotate(self):
        for node in self.walk():
            if id(node) in self.nodes:
                typ = self.changed_type(self.nodes[id(node)])
                if typ:
                    node._ref_vtype = typ
                    node._runtime_annotation = typ
            if isinstance(node, ast.arg) and getattr(node, '_ref_vtype', ''):
                node.annotation = ast.copy_location(ast.Name(id=node._ref_vtype, ctx=ast.Load()), node)
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                typ = self.changed_type(('return', id(node)))
                if typ:
                    node.returns = ast.copy_location(ast.Name(id=typ, ctx=ast.Load()), node)
            elif isinstance(node, ast.AnnAssign):
                typ = self.changed_type(self.key(node.target))
                if typ:
                    node.annotation = ast.copy_location(ast.Name(id=typ, ctx=ast.Load()), node)
        return self


def plan(tree, table, facts):
    if table is None or facts is None:
        return None
    return Plan(tree, table, facts).graph().validate().annotate()


def lower(tree, chosen, runtime_call):
    if chosen is None:
        return
    if not chosen.selected and not any(
            isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == 'list'
            or isinstance(n, ast.Subscript) and isinstance(n.slice, ast.Slice)
            or isinstance(n, ast.For) and isinstance(n.target, ast.Name) and n.target.id == '_'
            for n in ast.walk(tree)):
        return
    reserved = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)}

    def fresh_name():
        index = 0
        while f'py2v_loop_value{index}' in reserved:
            index += 1
        name = f'py2v_loop_value{index}'
        reserved.add(name)
        return name

    def ref(node):
        return getattr(node, '_ref_vtype', '').startswith('&pyrt.ListRef[')

    def items(node):
        typ = node._ref_vtype[len('&pyrt.ListRef['):-1]
        out = ast.copy_location(ast.Attribute(value=node, attr='items', ctx=ast.Load()), node)
        out._runtime_annotation = '[]' + typ
        out._ref_items = True
        return out

    def clone(node):
        return ast.copy_location(ast.Call(func=ast.Attribute(value=node, attr='copy', ctx=ast.Load()),
                                         args=[], keywords=[]), node)

    def wrap(node, like):
        call = runtime_call('list_ref', [node], like)
        call._api = '__py2v__.list_ref'
        call._runtime_annotation = like._ref_vtype
        call._ref_vtype = like._ref_vtype
        call._dynamic = False
        return call

    class Lower(ast.NodeTransformer):
        def visit(self, node):
            if getattr(node, '_list_identity_error', ''):
                return node
            return super().visit(node)

        def visit_List(self, node):
            self.generic_visit(node)
            if ref(node) and node._ref_vtype == '&pyrt.ListRef[Any]' and isinstance(node.ctx, ast.Load):
                node.elts = [elt if isinstance(elt, ast.Starred) else runtime_call('box', [elt], elt)
                             for elt in node.elts]
            return wrap(node, node) if ref(node) and isinstance(node.ctx, ast.Load) else node

        def visit_ListComp(self, node):
            self.generic_visit(node)
            return wrap(node, node) if ref(node) else node

        def visit_Assign(self, node):
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Subscript):
                target = node.targets[0]
                if isinstance(target.slice, ast.Slice) and ref(target.value):
                    value = self.visit(node.value)
                    if ref(value):
                        value = items(value)
                    bounds = target.slice
                    call = runtime_call('list_ref_assign_slice', [value, self.visit(target.value),
                        self.visit(bounds.lower) if bounds.lower is not None else ast.Constant(value=0),
                        self.visit(bounds.upper) if bounds.upper is not None else ast.Constant(value=0),
                        ast.Constant(value=bounds.lower is not None),
                        ast.Constant(value=bounds.upper is not None)], node)
                    call._api = '__py2v__.list_ref_assign_slice'
                    if bounds.step is not None:
                        call.args.insert(4, self.visit(bounds.step))
                        call.func.attr = 'list_ref_assign_slice_step'
                        call._api = '__py2v__.list_ref_assign_slice_step'
                    call._dynamic = False
                    return ast.copy_location(ast.Expr(value=call), node)
            self.generic_visit(node)
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Subscript):
                target = node.targets[0]
                if getattr(target.value, '_ref_items', False) \
                        and getattr(target.value, '_runtime_annotation', '') == '[]Any':
                    node.value = runtime_call('box', [node.value], node.value)
            if len(node.targets) == 1 and isinstance(node.targets[0], ast.Attribute):
                typ = getattr(node.targets[0], '_ref_vtype', '')
                if typ:
                    return ast.copy_location(ast.AnnAssign(target=node.targets[0],
                        annotation=ast.Name(id=typ, ctx=ast.Load()), value=node.value, simple=0), node)
            return node

        def visit_Delete(self, node):
            statements = []
            for target in node.targets:
                if (isinstance(target, ast.Subscript) and isinstance(target.slice, ast.Slice)
                        and ref(target.value)):
                    bounds = target.slice
                    name = ('list_ref_delete_slice_step' if bounds.step is not None
                            else 'list_ref_delete_slice')
                    args = [self.visit(target.value),
                            self.visit(bounds.lower) if bounds.lower is not None else ast.Constant(value=0),
                            self.visit(bounds.upper) if bounds.upper is not None else ast.Constant(value=0)]
                    if bounds.step is not None:
                        args.append(self.visit(bounds.step))
                    args += [ast.Constant(value=bounds.lower is not None),
                             ast.Constant(value=bounds.upper is not None)]
                    call = runtime_call(name, args, node)
                    call._api = '__py2v__.' + name
                    call._dynamic = False
                    statements.append(ast.copy_location(ast.Expr(value=call), node))
                else:
                    statements.append(ast.copy_location(ast.Delete(targets=[self.visit(target)]), node))
            return statements

        def visit_Subscript(self, node):
            was_ref = ref(node.value)
            self.generic_visit(node)
            if was_ref:
                if isinstance(node.ctx, ast.Store) and isinstance(node.slice, ast.Slice):
                    raise chosen.unsupported('py2v: shared-list slice assignment is not supported', node)
                node.value = items(node.value)
                if isinstance(node.slice, ast.Slice):
                    bounds = node.slice
                    name = 'list_ref_slice_step' if bounds.step is not None else 'list_ref_slice'
                    args = [node.value.value,
                            bounds.lower or ast.Constant(value=0),
                            bounds.upper or ast.Constant(value=0)]
                    if bounds.step is not None:
                        args.append(bounds.step)
                    args += [ast.Constant(value=bounds.lower is not None),
                             ast.Constant(value=bounds.upper is not None)]
                    copied = runtime_call(name, args, node)
                    copied._api = '__py2v__.' + name
                    copied._runtime_annotation = node.value._runtime_annotation
                    copied._dynamic = False
                    return wrap(copied, node) if ref(node) else copied
            elif isinstance(node.slice, ast.Slice) and chosen.entry(node).get('k') == 'list':
                if ref(node):
                    return wrap(clone(node), node)
                key = chosen.nodes.get(id(node))
                if key is not None and chosen.find(key) in chosen.mutation_roots:
                    return clone(node)
            return node

        def visit_Call(self, node):
            method_ref = isinstance(node.func, ast.Attribute) and ref(node.func.value)
            returns_ref = ref(node)
            borrows_ref = chosen.random_member(node) in ('shuffle', 'choice', 'choices', 'sample') \
                and node.args and ref(node.args[0])
            self.generic_visit(node)
            if borrows_ref:
                node.args[0] = items(node.args[0])
                return wrap(node, node) if returns_ref and chosen.random_member(node) in ('choices', 'sample') else node
            if (isinstance(node.func, ast.Attribute) and node.func.attr == 'join'
                    and chosen.entry(node.func.value).get('k') == 'str'):
                node.args = [items(a) if ref(a) else a for a in node.args]
            if getattr(node, '_api', '') == '__py2v__.list_ref':
                return node
            if method_ref:
                if node.func.attr in ('index', 'count', 'remove') or (
                        node.func.value._ref_vtype == '&pyrt.ListRef[Any]' and node.func.attr != 'copy'):
                    if node.keywords:
                        raise chosen.unsupported('py2v: dynamic shared-list method keywords are not supported', node)
                    result = runtime_call('invoke', [runtime_call('box', [node.func.value], node),
                        ast.Constant(value=node.func.attr)] +
                        [runtime_call('box', [a], a) for a in node.args], node)
                    return runtime_call('to_int', [result], node) if node.func.attr in ('index', 'count') else result
                node.func.value = items(node.func.value)
                if node.func.attr in ('extend',) and node.args and ref(node.args[0]):
                    node.args[0] = items(node.args[0])
                if node.func.attr == 'copy' and returns_ref:
                    return wrap(node, node)
            if isinstance(node.func, ast.Name) and getattr(node.func, '_binding', None) is None:
                name = node.func.id
                if name == 'repr' and node.args and ref(node.args[0]):
                    return runtime_call('str', [runtime_call('box', [node.args[0]], node)], node)
                if name in ('print', 'str'):
                    node.args = [runtime_call('str', [runtime_call('box', [a], a)], a)
                                 if ref(a) else a for a in node.args]
                elif name in ('len', 'sum', 'min', 'max', 'sorted', 'reversed', 'enumerate', 'zip',
                              'list', 'tuple', 'set', 'frozenset', 'all', 'any', 'bool'):
                    if name == 'bool' and node.args and ref(node.args[0]):
                        return runtime_call('truth', [runtime_call('box', [node.args[0]], node)], node)
                    node.args = [items(a) if ref(a) else a for a in node.args]
                    if name == 'list' and node.args:
                        copied = clone(node.args[0])
                        return wrap(copied, node) if returns_ref else copied
                    if returns_ref and name in ('sorted',):
                        return wrap(node, node)
            return node

        def visit_FormattedValue(self, node):
            self.generic_visit(node)
            if ref(node.value):
                if node.conversion == 97 or (node.format_spec is not None and node.format_spec.values):
                    raise chosen.unsupported('py2v: this shared-list format conversion is not supported', node)
                node.value = runtime_call('str', [runtime_call('box', [node.value], node)], node)
                node.conversion = -1
            return node

        def visit_For(self, node):
            if isinstance(node.target, ast.Name) and node.target.id == '_':
                uses = [n for stmt in node.body for n in ast.walk(stmt)
                        if isinstance(n, ast.Name) and n.id == '_'
                        and getattr(n, '_binding', None) == getattr(node.target, '_binding', None)]
                if any(isinstance(n.ctx, ast.Load) for n in uses):
                    name = fresh_name()
                    node.target.id = name
                    for use in uses:
                        use.id = name
            self.generic_visit(node)
            if ref(node.iter):
                node.iter = items(node.iter)
            return node

        def visit_comprehension(self, node):
            self.generic_visit(node)
            if ref(node.iter):
                node.iter = items(node.iter)
            return node

        def visit_BinOp(self, node):
            self.generic_visit(node)
            if isinstance(node.op, (ast.Add, ast.Mult)):
                if ref(node.left):
                    node.left = items(node.left)
                if ref(node.right):
                    node.right = items(node.right)
                if ref(node):
                    return wrap(node, node)
            return node

        def visit_Starred(self, node):
            self.generic_visit(node)
            if ref(node.value):
                node.value = items(node.value)
            return node

        def visit_AugAssign(self, node):
            self.generic_visit(node)
            if ref(node.target):
                if not isinstance(node.op, ast.Add):
                    raise chosen.unsupported('py2v: shared-list augmented operator is not supported', node)
                if ref(node.value):
                    node.value = items(node.value)
                # Keep the target so the backend can capture it before the RHS and
                # write the original object back after extending its shared descriptor.
                return node
            return node

        def visit_Compare(self, node):
            has_reference = ref(node.left) or any(ref(n) for n in node.comparators)
            self.generic_visit(node)
            if has_reference and len(node.ops) != 1:
                raise chosen.unsupported('py2v: chained shared-list comparison is not supported', node)
            if has_reference and len(node.ops) == 1 and isinstance(node.ops[0], (ast.Is, ast.IsNot)):
                node.left = runtime_call('object_identity', [runtime_call('box', [node.left], node.left)], node)
                node.comparators = [runtime_call('object_identity', [runtime_call('box', [n], n)], n)
                                    for n in node.comparators]
                node.ops = [ast.Eq() if isinstance(node.ops[0], ast.Is) else ast.NotEq()]
                return node
            if has_reference and len(node.ops) == 1 and isinstance(node.ops[0], (ast.Eq, ast.NotEq)):
                compared = runtime_call('eq', [runtime_call('box', [node.left], node.left),
                    runtime_call('box', [node.comparators[0]], node.comparators[0])], node)
                return (ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=compared), node)
                        if isinstance(node.ops[0], ast.NotEq) else compared)
            if has_reference and len(node.ops) == 1 and isinstance(node.ops[0], (ast.In, ast.NotIn)):
                compared = runtime_call('has', [runtime_call('box', [node.comparators[0]], node),
                    runtime_call('box', [node.left], node)], node)
                return (ast.copy_location(ast.UnaryOp(op=ast.Not(), operand=compared), node)
                        if isinstance(node.ops[0], ast.NotIn) else compared)
            if has_reference and any(isinstance(op, (ast.Lt, ast.LtE, ast.Gt, ast.GtE)) for op in node.ops):
                raise chosen.unsupported('py2v: shared-list ordering comparison is not supported', node)
            if all(isinstance(op, (ast.Eq, ast.NotEq, ast.Lt, ast.LtE, ast.Gt, ast.GtE)) for op in node.ops):
                if ref(node.left):
                    node.left = items(node.left)
                node.comparators = [items(n) if ref(n) else n for n in node.comparators]
            elif all(isinstance(op, (ast.In, ast.NotIn)) for op in node.ops):
                node.comparators = [items(n) if ref(n) else n for n in node.comparators]
            return node

    Lower().visit(tree)
