import ast
from enum import Enum
from typing import List, Union, Optional

TYPES = {'str': 'string'}
NAMES = {'__name__': '@MOD',
        'main': 'main_'}
LITERALS = {'__main__': 'main'}
CALLS = {'print': 'println'}

 
class Type:
    def __init__(self, typ: Optional[str] = None):
        self.typ = TYPES.get(typ, typ)  # None -> unknown type, '' -> none/no return

    def __str__(self):
        if self.typ is not None:
            return self.typ
        else:
            return '<unknown>'
        
    @classmethod
    def from_annotation(cls, annotation):
        if annotation is None:
            return cls()
        elif isinstance(annotation, ast.Constant):
            assert isinstance(annotation.value, str)
            return cls(annotation.value)
        elif isinstance(annotation, ast.Name):
            return cls(annotation.id)
        else:
            raise Exception(f'cannot handle type {type(annotation)}')


class Node:
    def __init__(self, parent: 'Node' = None, children: List['Node'] = None):
        self.parent = parent
        self.children = children or []

        for child in self.children:
            child.parent = self

    def __str__(self):
        return f'<{self.__class__.__qualname__}({" ".join(map(str, self.children))})>'
    
    def add_child(self, child: 'Node'):
        child.parent = self
        self.children.append(child)
    
    def find(self, cls: 'Node') -> 'Node':
        """ Find the first parent node that is a {cls}. """
        if self.parent is None:
            raise Exception(f'cannot find {cls}')
        if isinstance(self.parent, cls):
            return self.parent
        return self.parent.find(cls)


class ScopeDict(dict):
    def ensure(self, ident):
        if first := super().get(ident.name, False):
            first.is_mut = True
            return True
        self[ident.name] = ident
        return False


class ScopedNode(Node):
    def __init__(self, *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.scope = ScopeDict()


class File(ScopedNode):
    def __str__(self):
        return '\n'.join(map(str, self.children))


class Literal(Node):
    def __init__(self, value: Union[int, float, bool, str, None], *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.value = LITERALS.get(value, value)

    def __str__(self) -> str:
        if isinstance(self.value, (int, float)):
            return str(self.value)
        elif isinstance(self.value, bool) or self.value is None:
            return str(self.value).lower()
        elif isinstance(self.value, str):
            return f'"{self.value}"'
        else:
            raise Exception(f'cannot handle literal type {type(self.value)}')
        

class ModuleDecl(Node):
    def __init__(self, name: str, *args_, **kwargs):
        super().__init__(*args_, **kwargs)
        self.name = name


    def __str__(self):
        return f'module {self.name}'


class Ident(Node):
    def __init__(self, name: str, typ: Optional[Type] = None, is_mut: bool = False, *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.name = NAMES.get(name, name)
        self.typ = typ or Type()
        self.is_mut = is_mut
        
    def __str__(self):
        buf = []
        if self.is_mut:
            buf.append('mut')
        buf.append(self.name)
        if isinstance(self.parent, FunctionDecl):
            buf.append(self.typ)
        return self.name


class StructDecl(Node):
    pass


class FunctionDecl(ScopedNode):
    def __init__(self, name: str, args: Optional[List[Ident]] = None, returns: Optional[List[Type]] = None,
                 *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.name = NAMES.get(name, name)
        self.args = args or []
        self.returns = returns or []
        
    def __str__(self):
        buf = []
        if isinstance(self.parent, StructDecl):
            buf.append(f'fn ({self.args[0]} {self.parent.name}) {self.name}({", ".join(map(str, self.args))}) {{')
        else:
            buf.append(f'fn {self.name}({", ".join(map(str, self.args))}) {{')
        
        for child in self.children:
            buf.append(str(child))

        buf.append('}')
        return '\n'.join(buf)
    
    
class FunctionCall(Node):
    def __init__(self, name: str, module: str = 'main', left: Optional[Node] = None, *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.name = NAMES.get(name, name)
        self.name = CALLS.get(self.name, self.name)
        self.module = module
        self.left = left
        
    def __str__(self):
        buf = []
        if self.module not in ('builtin', 'strconv', 'main') or self.module != self.find(cls=File).children[0].name:
            buf.append(self.module)
        if self.left:
            buf.append(str(self.left))
        buf.append(f'{self.name}({", ".join(map(str, self.children))})')
        
        return '.'.join(buf)


class Assign(Node):
    def __init__(self, value: Node, *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.value = value

    def __str__(self):
        buf = []
        op = ':='
        for child in self.children:
            buf.append(str(child))
            if isinstance(self.parent, ScopedNode) and self.parent.scope.ensure(child):
                op = '='
        buf.append(op)
        buf.append(', '.join([str(self.value)] * len(self.children)))  # TODO: This will break with non-pure function calls, should fix later
        
        return ' '.join(buf)


class Infix(Node):
    def __init__(self, left: Node, right: Node, op: str, *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.left = left
        self.right = right
        self.op = op

    def __str__(self):
        return f'{self.left} {self.op} {self.right}'


class If(Node):
    def __init__(self, test: Node, else_: Optional[List[Node]] = None, *_args, **_kwargs):
        super().__init__(*_args, **_kwargs)
        self.test = test
        self.else_ = else_ or []

    def __str__(self):
        buf = [f'if {self.test} {{']
        buf.extend(map(str, self.children))
        buf.append('}')
        
        if self.else_:
            buf.append('else {')
            buf.extend(map(str, self.else_))
            buf.append('}')
            
        return '\n'.join(buf)


class Return(Node):
    def __str__(self):
        if self.children:
            return f'return {", ".join(map(str, self.children))}'
        return 'return'

class Import(Node):
    def __str__(self):
        if self.children == 1:
            return f'import {self.children[0]}'
        return f'import {self.children[0]} {{{", ".join(map(str, self.children[1:]))}}}'

"""
class SelectorExpr(Expr):
    expr: Expr
    field_name: str
    expr_type: int
    typ: str


class Module(Stmt):
    name: str
    expr: Expr
    is_skipped: bool


class StructField(Node):
    name: str
    default_expr: Expr
    has_default_expr: bool
    attrs: List[str]
    is_public: bool
    typ: str


class Field(Node):
    name: str
    typ: str


class ConstField(Node):
    mod: str
    name: str
    expr: Expr
    is_pub: bool
    typ: str


class ConstDecl(Stmt):
    is_pub: bool
    fields: List[ConstField]


class StructDecl(Stmt):
    name: str
    fields: List[StructField]
    is_pub: bool
    language: Language
    is_union: bool
    attrs: List[str]


class Arg(Node):
    name: str
    is_mut: bool
    typ: str
    is_hidden: bool


class FnDecl(Stmt):
    name: str
    mod: str = 'main'
    args: List[Arg] = tuple()
    is_deprecated: bool = False
    is_pub: bool = True
    is_variadic: bool = False
    is_anon: bool = False
    receiver: Field = None
    is_method: bool = False
    rec_mut: bool = True
    rec_share: None  # TODO: table.ShareType
    language: Language = Language.V
    # no_body: bool = True
    # ctdefine: str
    is_generic: bool = False
    stmts: List[Stmt] = tuple()
    return_type: str = ''
    
    def __str__(self):
        buf = [f'fn {self.name}({", ".join(map(str, self.args))}) {self.return_type}{{']
        
        for stmt in self.stmts:
            buf.append(str(stmt))
            
        buf.append('}')
        return '\n'.join(buf)

class InterfaceDecl(Stmt):
    name: str
    field_names: List[str]
    is_pub: bool
    methods: List[FnDecl]


class StructInitField(Node):
    expr: Expr
    name: str
    typ: str
    expected_type: int


class StructInit(Expr):
    is_short: bool
    typ: str
    fields: List[StructInitField]


class Import(Stmt):
    mod: str
    alias: str
    syms: List[str]
    
    def __hash__(self):
        return hash(self.mod)


class AnonFn(Expr):
    decl: FnDecl
    typ: str


class BranchStmt(Stmt):
    tok: str


class CallArg(Node):
    is_mut: bool = True
    share: None  # TODO: table.ShareType
    expr: Expr
    typ: str


class OrKind(Enum):
    absent = 0
    block = 1
    propagate = 2


class OrExpr(Expr):
    stmts: List[Stmt]
    kind:  OrKind


class CallExpr(Expr):
    left: Expr = None
    mod: str = 'main'
    name: str
    args: List[CallArg] = tuple()
    language: Language = Language.V
    or_block: OrExpr = None
    generic_type: str = None
    
    def __init__(self, name: str, args, *args_, **kwargs):
        self.name = name
        self.args = args
        super().__init__(*args_, **kwargs)
    
    def __str__(self):
        buf = []
        if not self.mod == 'main':
            buf.append(f'{self.mod}.')
        if self.left:
            buf.append(f'{self.left}.')
        buf.append(f'{self.name}(')
        buf.append(', '.join(map(str, self.args)))
        buf.append(')')
        return ''.join(buf)


class Return(Stmt):
    exprs: List[Expr]
    types: List[int]

class Var(Node):
    name: str
    expr: Expr
    share: None  # TODO: table.ShareType
    is_mut: bool
    is_arg: bool
    typ: str
    is_used: bool
    is_changed: bool

class GlobalDecl(Stmt):
    name: str
    expr: Expr
    has_expr: bool
    typ: str


class File(Node):
    mod: Module
    stmts: List[Stmt] = tuple()
    imports: List[Import] = tuple()
    
    def __str__(self):
        buf = []
        for imp in self.imports:
            buf.append(str(imp))

        for child in self.children:
            buf.append(str(child))
            
        return '\n'.join(buf)


class InfixExpr(Expr):
    op: str
    left: Expr
    right: Expr
    
    def __str__(self):
        return f'{self.left} {self.op} {self.right}'


class PostfixExpr(Expr):
    op: str
    expr: Expr
    auto_locked: str
    
    
class PrefixExpr(Expr):
    op: str
    right: Expr


class IndexExpr(Expr):
    left: Expr
    index: Expr
    left_type: int
    is_setter: bool


class IfBranch(Node):
    cond: Expr
    stmts: List[Stmt]
    smartcast: bool
    left_as_name: str


class IfExpr(Expr):
    tok_kind: str
    left: Expr
    branches: List[IfBranch]
    is_expr: bool
    typ: str
    has_else: bool


class UnsafeExpr(Expr):
    stmts: List[Stmt]


class LockExpr(Expr):
    stmts: List[Stmt]
    is_rlock: bool
    lockeds:  List[Ident]
    is_expr: bool
    typ: str


class MatchBranch(Node):
    exprs: List[Expr]
    stmts: List[Stmt]
    is_else: bool


class MatchExpr(Expr):
    tok_kind: str
    cond: Expr
    branches: List[MatchBranch]
    is_mut: bool
    var_name: str
    is_expr: bool
    return_type: int
    cond_type: int
    expected_type: int
    is_sum_type: bool
    is_interface: bool


class CompIf(Stmt):
    val: str
    stmts: List[Stmt]
    is_not: bool
    is_opt: bool
    has_else: bool
    else_stmts: List[Stmt]


class CompFor(Stmt):
    val_var: str
    stmts: List[Stmt]
    typ: str


class ForStmt(Stmt):
    cond: Expr
    stmts: List[Stmt]
    is_inf: bool


class ForInStmt(Stmt):
    key_var: str
    val_var: str
    cond: Expr
    is_range: bool
    high: Expr
    stmts: List[Stmt]
    key_type: int
    val_type: int
    cond_type: int
    kind: str


class ForCStmt(Stmt):
    init: Stmt
    has_init: bool
    cond: Expr
    has_cond: bool
    inc: Stmt
    has_inc: bool
    stmts: List[Stmt]


class HashStmt(Stmt):
    val: str
    mod: str


class Lambda(Node):
    name: str


class AssignStmt(Stmt):
    right: Expr
    op: str = ':='
    left: Expr
    
    def __str__(self):
        return f'{self.left} {self.op} {self.right}'


class AsCast(Expr):
    expr: Expr
    typ: str
    expr_type: int


class Attr(Stmt):
    name: str
    is_string: bool


class EnumVal(Stmt):
    enum_name: str
    val: str
    mod: str
    typ: str


class EnumField(Node):
    name: str
    expr: Expr
    has_expr: bool


class EnumDecl(Stmt):
    name: str
    is_pub: bool
    is_flag: bool
    is_multi_allowed: bool
    fields: List[EnumField]


class AliasTypeDecl(TypeDecl):
    name: str
    is_pub: bool
    parent_type: int


class SumTypeDecl(TypeDecl):
    name: str
    is_pub: bool
    sub_types: List[int]


class FnTypeDecl(TypeDecl):
    name: str
    is_pub: bool
    typ: str


class DeferStmt(Stmt):
    stmts: List[Stmt]
    ifdef: str


class UnsafeStmt(Stmt):
    stmts: List[Stmt]


class ParExpr(Expr):
    expr: Expr


class GoStmt(Stmt):
    call_expr: Expr


class GotoLabel(Stmt):
    name: str


class GotoStmt(Stmt):
    name: str


class ArrayInit(Expr):
    exprs: List[Expr]
    is_fixed: bool
    has_val: bool
    mod: str
    len_expr: Expr
    cap_expr: Expr
    default_expr: Expr
    has_len: bool
    has_cap: bool
    has_default: bool
    is_interface: bool
    interface_types: List[int]
    interface_type: int
    elem_type: int
    typ: str


class MapInit(Expr):
    keys: List[Expr]
    vals: List[Expr]
    typ: str
    key_type: int
    value_type: int


class RangeExpr(Expr):
    low: Expr
    high: Expr
    has_high: bool
    has_low:  bool


class CastExpr(Expr):
    expr: Expr
    arg: Expr
    typ: str
    typname: str
    expr_type: int
    has_arg: bool


class AssertStmt(Stmt):
    expr: Expr


class IfGuardExpr(Expr):
    var_name:  str
    expr: Expr
    expr_type: int


class Assoc(Expr):
    var_name: str
    fields: List[str]
    exprs: List[Expr]
    typ: str


class SizeOf(Expr):
    is_type: bool
    typ: str
    type_name: str
    expr: Expr


class TypeOf(Expr):
    expr: Expr
    expr_type: int


class ConcatExpr(Expr):
    vals: List[Expr]
    return_type: int


class ComptimeCall(Expr):
    method_name: str
    left: Expr
    is_vweb: bool
    args_var: str
    sym: str


class none(Node):
    foo: int
"""
