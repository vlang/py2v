from enum import Enum
from typing import Sequence


class Language(Enum):
    V = 0
    C = 1
    JS = 2


class Object:
    def __init__(self, *_, **kwargs):
        for key in kwargs:
            setattr(self, key, kwargs[key])
            
    def __str__(self):
        attrs = []
        for attr in dir(self):
            if not attr.startswith('__'):
                attrs.append(f'{attr}={getattr(self, attr)}')
        return f'<{self.__class__.__qualname__}({" ".join(attrs)})>'


class Expr(Object):
    pass


class Stmt(Object):
    pass


class TypeDecl(Stmt):
    pass


class Block(Stmt):
    stmts: Sequence[Stmt]


class ExprStmt(Stmt):
    expr: Expr
    typ: str


class IntegerLiteral(Expr):
    val: str
    
    def __str__(self):
        return self.val


class FloatLiteral(Expr):
    val: str
    
    def __str__(self):
        return self.val


class StringLiteral(Expr):
    val: str = ''
    is_raw: bool = False
    language: Language = Language.V
    
    def __str__(self):
        return f"'{self.val}'"  # TODO: escape


class CharLiteral(Expr):
    val: str

    def __str__(self):
        return f"`{self.val}`"

class BoolLiteral(Expr):
    val: str
    
    def __str__(self):
        return self.val


class SelectorExpr(Expr):
    expr: Expr
    field_name: str
    expr_type: int
    typ: str


class Module(Stmt):
    name: str
    expr: Expr
    is_skipped: bool


class StructField(Object):
    name: str
    default_expr: Expr
    has_default_expr: bool
    attrs: Sequence[str]
    is_public: bool
    typ: str


class Field(Object):
    name: str
    typ: str


class ConstField(Object):
    mod: str
    name: str
    expr: Expr
    is_pub: bool
    typ: str


class ConstDecl(Stmt):
    is_pub: bool
    fields: Sequence[ConstField]


class StructDecl(Stmt):
    name: str
    fields: Sequence[StructField]
    is_pub: bool
    language: Language
    is_union: bool
    attrs: Sequence[str]


class Arg(Object):
    name: str
    is_mut: bool
    typ: str
    is_hidden: bool


class FnDecl(Stmt):
    name: str
    mod: str = 'main'
    args: Sequence[Arg] = tuple()
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
    stmts: Sequence[Stmt] = tuple()
    return_type: str = ''
    
    def __str__(self):
        buf = [f'fn {self.name}({", ".join(map(str, self.args))}) {self.return_type}{{']
        
        for stmt in self.stmts:
            buf.append(str(stmt))
            
        buf.append('}')
        return '\n'.join(buf)

class InterfaceDecl(Stmt):
    name: str
    field_names: Sequence[str]
    is_pub: bool
    methods: Sequence[FnDecl]


class StructInitField(Object):
    expr: Expr
    name: str
    typ: str
    expected_type: int


class StructInit(Expr):
    is_short: bool
    typ: str
    fields: Sequence[StructInitField]


class Import(Stmt):
    mod: str
    alias: str
    syms: Sequence[str]
    
    def __hash__(self):
        return hash(self.mod)


class AnonFn(Expr):
    decl: FnDecl
    typ: str


class BranchStmt(Stmt):
    tok: str


class CallArg(Object):
    is_mut: bool = True
    share: None  # TODO: table.ShareType
    expr: Expr
    typ: str


class OrKind(Enum):
    absent = 0
    block = 1
    propagate = 2


class OrExpr(Expr):
    stmts: Sequence[Stmt]
    kind:  OrKind


class CallExpr(Expr):
    left: Expr = None
    mod: str = 'main'
    name: str
    args: Sequence[CallArg] = tuple()
    language: Language = Language.V
    or_block: OrExpr = None
    generic_type: str = None
    
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
    exprs: Sequence[Expr]
    types: Sequence[int]

"""
class Var(Object):
    name: str
    expr: Expr
    share: None  # TODO: table.ShareType
    is_mut: bool
    is_arg: bool
    typ: str
    is_used: bool
    is_changed: bool
"""

class GlobalDecl(Stmt):
    name: str
    expr: Expr
    has_expr: bool
    typ: str


class File(Object):
    mod: Module
    stmts: Sequence[Stmt] = tuple()
    imports: Sequence[Import] = tuple()
    
    def __str__(self):
        buf = [f'module {self.mod.name}']
        for imp in self.imports:
            buf.append(str(imp))

        for stmt in self.stmts:
            buf.append(str(stmt))
            
        return '\n'.join(buf)


class Ident(Expr):
    language: Language = Language.V
    mod: str = 'main'
    name: str
    is_mut: bool = False
    
    def __hash__(self):
        return hash(self.name)
    
    def __str__(self):
        buf = []
        if self.is_mut:
            buf.append('mut')
        buf.append(self.name)
        return ' '.join(buf)


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


class IfBranch(Object):
    cond: Expr
    stmts: Sequence[Stmt]
    smartcast: bool
    left_as_name: str


class IfExpr(Expr):
    tok_kind: str
    left: Expr
    branches: Sequence[IfBranch]
    is_expr: bool
    typ: str
    has_else: bool


class UnsafeExpr(Expr):
    stmts: Sequence[Stmt]


class LockExpr(Expr):
    stmts: Sequence[Stmt]
    is_rlock: bool
    lockeds:  Sequence[Ident]
    is_expr: bool
    typ: str


class MatchBranch(Object):
    exprs: Sequence[Expr]
    stmts: Sequence[Stmt]
    is_else: bool


class MatchExpr(Expr):
    tok_kind: str
    cond: Expr
    branches: Sequence[MatchBranch]
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
    stmts: Sequence[Stmt]
    is_not: bool
    is_opt: bool
    has_else: bool
    else_stmts: Sequence[Stmt]


class CompFor(Stmt):
    val_var: str
    stmts: Sequence[Stmt]
    typ: str


class ForStmt(Stmt):
    cond: Expr
    stmts: Sequence[Stmt]
    is_inf: bool


class ForInStmt(Stmt):
    key_var: str
    val_var: str
    cond: Expr
    is_range: bool
    high: Expr
    stmts: Sequence[Stmt]
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
    stmts: Sequence[Stmt]


class HashStmt(Stmt):
    val: str
    mod: str


class Lambda(Object):
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


class EnumField(Object):
    name: str
    expr: Expr
    has_expr: bool


class EnumDecl(Stmt):
    name: str
    is_pub: bool
    is_flag: bool
    is_multi_allowed: bool
    fields: Sequence[EnumField]


class AliasTypeDecl(TypeDecl):
    name: str
    is_pub: bool
    parent_type: int


class SumTypeDecl(TypeDecl):
    name: str
    is_pub: bool
    sub_types: Sequence[int]


class FnTypeDecl(TypeDecl):
    name: str
    is_pub: bool
    typ: str


class DeferStmt(Stmt):
    stmts: Sequence[Stmt]
    ifdef: str


class UnsafeStmt(Stmt):
    stmts: Sequence[Stmt]


class ParExpr(Expr):
    expr: Expr


class GoStmt(Stmt):
    call_expr: Expr


class GotoLabel(Stmt):
    name: str


class GotoStmt(Stmt):
    name: str


class ArrayInit(Expr):
    exprs: Sequence[Expr]
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
    interface_types: Sequence[int]
    interface_type: int
    elem_type: int
    typ: str


class MapInit(Expr):
    keys: Sequence[Expr]
    vals: Sequence[Expr]
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
    fields: Sequence[str]
    exprs: Sequence[Expr]
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
    vals: Sequence[Expr]
    return_type: int


class ComptimeCall(Expr):
    method_name: str
    left: Expr
    is_vweb: bool
    args_var: str
    sym: str


class none(Object):
    foo: int
