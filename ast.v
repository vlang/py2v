module main

// Location information for AST nodes
pub struct Location {
pub:
	lineno         int
	col_offset     int
	end_lineno     int
	end_col_offset int
}

// Context types for Name nodes
pub type ExprContext = Load | Store | Del

pub struct Load {}

pub struct Store {}

pub struct Del {}

// Operator types
pub type BoolOperator = And | Or

pub struct And {}

pub struct Or {}

pub type UnaryOperator = Invert | Not | UAdd | USub

pub struct Invert {}

pub struct Not {}

pub struct UAdd {}

pub struct USub {}

pub type Operator = Add
	| Sub
	| Mult
	| MatMult
	| Div
	| Mod
	| Pow
	| LShift
	| RShift
	| BitOr
	| BitXor
	| BitAnd
	| FloorDiv

pub struct Add {}

pub struct Sub {}

pub struct Mult {}

pub struct MatMult {}

pub struct Div {}

pub struct Mod {}

pub struct Pow {}

pub struct LShift {}

pub struct RShift {}

pub struct BitOr {}

pub struct BitXor {}

pub struct BitAnd {}

pub struct FloorDiv {}

pub type CmpOp = Eq | NotEq | Lt | LtE | Gt | GtE | Is | IsNot | In | NotIn

pub struct Eq {}

pub struct NotEq {}

pub struct Lt {}

pub struct LtE {}

pub struct Gt {}

pub struct GtE {}

pub struct Is {}

pub struct IsNot {}

pub struct In {}

pub struct NotIn {}

// Forward declarations - all expression and statement types
pub type Expr = Constant
	| Name
	| BinOp
	| UnaryOp
	| BoolOp
	| Compare
	| Call
	| Attribute
	| Subscript
	| Slice
	| List
	| Tuple
	| Dict
	| Set
	| IfExp
	| Lambda
	| ListComp
	| SetComp
	| DictComp
	| GeneratorExp
	| Await
	| Yield
	| YieldFrom
	| FormattedValue
	| JoinedStr
	| NamedExpr
	| Starred

pub type Stmt = FunctionDef
	| AsyncFunctionDef
	| ClassDef
	| Return
	| Delete
	| Assign
	| AugAssign
	| AnnAssign
	| For
	| AsyncFor
	| While
	| If
	| With
	| AsyncWith
	| Raise
	| Try
	| Assert
	| Import
	| ImportFrom
	| Global
	| Nonlocal
	| ExprStmt
	| Pass
	| Break
	| Continue

// Module is the root node
pub struct Module {
pub mut:
	body              []Stmt
	loc               Location
	docstring_comment ?string
}

// Expressions
pub struct Constant {
pub mut:
	value        ConstantValue
	kind         ?string
	loc          Location
	v_annotation ?string
}

pub type ConstantValue = int | i64 | f64 | string | bool | BytesValue | NoneValue | EllipsisValue

pub struct BytesValue {
pub:
	data []u8
}

pub struct NoneValue {}

pub struct EllipsisValue {}

pub struct Name {
pub mut:
	id           string
	ctx          ExprContext
	loc          Location
	is_mutable   bool
	v_annotation ?string
}

pub struct BinOp {
pub mut:
	left         Expr
	op           Operator
	right        Expr
	loc          Location
	v_annotation ?string
}

pub struct UnaryOp {
pub mut:
	op           UnaryOperator
	operand      Expr
	loc          Location
	v_annotation ?string
}

pub struct BoolOp {
pub mut:
	op           BoolOperator
	values       []Expr
	loc          Location
	v_annotation ?string
}

pub struct Compare {
pub mut:
	left         Expr
	ops          []CmpOp
	comparators  []Expr
	loc          Location
	v_annotation ?string
}

pub struct Call {
pub mut:
	func         Expr
	args         []Expr
	keywords     []Keyword
	loc          Location
	v_annotation ?string
}

pub struct Keyword {
pub mut:
	arg   ?string
	value Expr
	loc   Location
}

pub struct Attribute {
pub mut:
	value        Expr
	attr         string
	ctx          ExprContext
	loc          Location
	v_annotation ?string
}

pub struct Subscript {
pub mut:
	value         Expr
	slice         Expr
	ctx           ExprContext
	loc           Location
	v_annotation  ?string
	is_annotation bool
}

pub struct Slice {
pub mut:
	lower ?Expr
	upper ?Expr
	step  ?Expr
	loc   Location
}

pub struct List {
pub mut:
	elts         []Expr
	ctx          ExprContext
	loc          Location
	v_annotation ?string
}

pub struct Tuple {
pub mut:
	elts         []Expr
	ctx          ExprContext
	loc          Location
	v_annotation ?string
}

pub struct Dict {
pub mut:
	keys         []?Expr
	values       []Expr
	loc          Location
	v_annotation ?string
}

pub struct Set {
pub mut:
	elts         []Expr
	loc          Location
	v_annotation ?string
}

pub struct IfExp {
pub mut:
	test   Expr
	body   Expr
	orelse Expr
	loc    Location
}

pub struct Lambda {
pub mut:
	args Arguments
	body Expr
	loc  Location
}

pub struct ListComp {
pub mut:
	elt        Expr
	generators []Comprehension
	loc        Location
}

pub struct SetComp {
pub mut:
	elt        Expr
	generators []Comprehension
	loc        Location
}

pub struct DictComp {
pub mut:
	key        Expr
	value      Expr
	generators []Comprehension
	loc        Location
}

pub struct GeneratorExp {
pub mut:
	elt        Expr
	generators []Comprehension
	loc        Location
}

pub struct Comprehension {
pub mut:
	target   Expr
	iter     Expr
	ifs      []Expr
	is_async bool
}

pub struct Await {
pub mut:
	value Expr
	loc   Location
}

pub struct Yield {
pub mut:
	value ?Expr
	loc   Location
}

pub struct YieldFrom {
pub mut:
	value Expr
	loc   Location
}

pub struct FormattedValue {
pub mut:
	value       Expr
	conversion  int
	format_spec ?Expr
	loc         Location
}

pub struct JoinedStr {
pub mut:
	values []Expr
	loc    Location
}

pub struct NamedExpr {
pub mut:
	target Expr
	value  Expr
	loc    Location
}

pub struct Starred {
pub mut:
	value Expr
	ctx   ExprContext
	loc   Location
}

// Statements
pub struct FunctionDef {
pub mut:
	name            string
	args            Arguments
	body            []Stmt
	decorator_list  []Expr
	returns         ?Expr
	type_comment    ?string
	loc             Location
	is_generator    bool
	is_void         bool
	mutable_vars    []string
	is_class_method bool
	class_name      string
}

pub struct AsyncFunctionDef {
pub mut:
	name            string
	args            Arguments
	body            []Stmt
	decorator_list  []Expr
	returns         ?Expr
	type_comment    ?string
	loc             Location
	is_generator    bool
	is_void         bool
	mutable_vars    []string
	is_class_method bool
	class_name      string
}

pub struct Arguments {
pub mut:
	posonlyargs []Arg
	args        []Arg
	vararg      ?Arg
	kwonlyargs  []Arg
	kw_defaults []?Expr
	kwarg       ?Arg
	defaults    []Expr
}

pub struct Arg {
pub mut:
	arg          string
	annotation   ?Expr
	type_comment ?string
	loc          Location
}

pub struct ClassDef {
pub mut:
	name           string
	bases          []Expr
	keywords       []Keyword
	body           []Stmt
	decorator_list []Expr
	loc            Location
	declarations   map[string]string
}

pub struct Return {
pub mut:
	value ?Expr
	loc   Location
}

pub struct Delete {
pub mut:
	targets []Expr
	loc     Location
}

pub struct Assign {
pub mut:
	targets           []Expr
	value             Expr
	type_comment      ?string
	loc               Location
	redefined_targets []string
}

pub struct AugAssign {
pub mut:
	target Expr
	op     Operator
	value  Expr
	loc    Location
}

pub struct AnnAssign {
pub mut:
	target     Expr
	annotation Expr
	value      ?Expr
	simple     int
	loc        Location
}

pub struct For {
pub mut:
	target       Expr
	iter         Expr
	body         []Stmt
	orelse       []Stmt
	type_comment ?string
	loc          Location
	level        int
}

pub struct AsyncFor {
pub mut:
	target       Expr
	iter         Expr
	body         []Stmt
	orelse       []Stmt
	type_comment ?string
	loc          Location
	level        int
}

pub struct While {
pub mut:
	test   Expr
	body   []Stmt
	orelse []Stmt
	loc    Location
	level  int
}

pub struct If {
pub mut:
	test   Expr
	body   []Stmt
	orelse []Stmt
	loc    Location
	level  int
}

pub struct With {
pub mut:
	items        []WithItem
	body         []Stmt
	type_comment ?string
	loc          Location
}

pub struct WithItem {
pub mut:
	context_expr  Expr
	optional_vars ?Expr
}

pub struct AsyncWith {
pub mut:
	items        []WithItem
	body         []Stmt
	type_comment ?string
	loc          Location
}

pub struct Raise {
pub mut:
	exc   ?Expr
	cause ?Expr
	loc   Location
}

pub struct Try {
pub mut:
	body      []Stmt
	handlers  []ExceptHandler
	orelse    []Stmt
	finalbody []Stmt
	loc       Location
}

pub struct ExceptHandler {
pub mut:
	typ  ?Expr
	name ?string
	body []Stmt
	loc  Location
}

pub struct Assert {
pub mut:
	test Expr
	msg  ?Expr
	loc  Location
}

pub struct Import {
pub mut:
	names []Alias
	loc   Location
}

pub struct ImportFrom {
pub mut:
	mod   ?string
	names []Alias
	level int
	loc   Location
}

pub struct Alias {
pub mut:
	name   string
	asname ?string
	loc    Location
}

pub struct Global {
pub mut:
	names []string
	loc   Location
}

pub struct Nonlocal {
pub mut:
	names []string
	loc   Location
}

pub struct ExprStmt {
pub mut:
	value Expr
	loc   Location
}

pub struct Pass {
pub mut:
	loc Location
}

pub struct Break {
pub mut:
	loc Location
}

pub struct Continue {
pub mut:
	loc Location
}

// Helper functions to create locations
pub fn make_loc(lineno int, col_offset int, end_lineno int, end_col_offset int) Location {
	return Location{
		lineno:         lineno
		col_offset:     col_offset
		end_lineno:     end_lineno
		end_col_offset: end_col_offset
	}
}
