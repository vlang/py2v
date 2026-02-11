module main

import x.json2

// Extract type annotation from v_annotation or inferred_annotation
fn parse_type_annotation(m map[string]json2.Any) ?string {
	// First try v_annotation (string)
	if raw_ann := m['v_annotation'] {
		return ?string(raw_ann.str())
	}
	// Then try inferred_annotation (object with id field)
	if raw_inf := m['inferred_annotation'] {
		inf_map := raw_inf.as_map()
		typ := inf_map['_type'] or { json2.Any('') }.str()

		// Handle Name annotation (simple types like 'int', 'str')
		if typ == 'Name' {
			if id := inf_map['id'] {
				name := id.str()
				// Map Python types to V types using the v_type_map from types.v
				return ?string(map_type(name))
			}
		}

		// Handle Subscript annotation (generic types like 'List[int]', 'Dict[str, int]')
		if typ == 'Subscript' {
			value_map := (inf_map['value'] or { json2.Any('') }).as_map()
			value_type := (value_map['_type'] or { json2.Any('') }).str()

			if value_type == 'Name' {
				container := (value_map['id'] or { json2.Any('') }).str()
				// Parse the slice to get the element type
				slice_map := (inf_map['slice'] or { json2.Any('') }).as_map()
				slice_type := (slice_map['_type'] or { json2.Any('') }).str()

				mut elem_type := 'Any'
				if slice_type == 'Name' {
					elem_name := (slice_map['id'] or { json2.Any('') }).str()
					elem_type = match elem_name {
						'int' { 'int' }
						'float' { 'f64' }
						'str' { 'string' }
						'bool' { 'bool' }
						else { elem_name }
					}
				}

				// Map container types
				return ?string(match container {
					'list', 'List' { '[]${elem_type}' }
					'tuple', 'Tuple' { '[]${elem_type}' }
					'set', 'Set' { '[]${elem_type}' }
					'dict', 'Dict' { 'map[string]${elem_type}' }
					else { '[]${elem_type}' }
				})
			}
		}
	}
	return none
}

// Parse JSON AST string into Module
pub fn parse_ast(json_str string) !Module {
	raw := json2.raw_decode(json_str)!
	return parse_module(raw.as_map())
}

// Parse a Module node
fn parse_module(m map[string]json2.Any) !Module {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut docstring := ?string(none)
	if raw_doc := m['docstring_comment'] {
		s := raw_doc.str()
		if s.len > 0 {
			docstring = s
		}
	}
	return Module{
		body:              body
		loc:               parse_location(m)
		docstring_comment: docstring
	}
}

// Parse location from a node map
fn parse_location(m map[string]json2.Any) Location {
	return Location{
		lineno:         m['lineno'] or { json2.Any(0) }.int()
		col_offset:     m['col_offset'] or { json2.Any(0) }.int()
		end_lineno:     m['end_lineno'] or { json2.Any(0) }.int()
		end_col_offset: m['end_col_offset'] or { json2.Any(0) }.int()
	}
}

// Parse a statement node
fn parse_stmt(m map[string]json2.Any) ?Stmt {
	node_type := m['_type'] or { return none }.str()
	match node_type {
		'FunctionDef' {
			return Stmt(parse_function_def(m))
		}
		'AsyncFunctionDef' {
			return Stmt(parse_async_function_def(m))
		}
		'ClassDef' {
			return Stmt(parse_class_def(m))
		}
		'Return' {
			return Stmt(parse_return(m))
		}
		'Delete' {
			return Stmt(parse_delete(m))
		}
		'Assign' {
			return Stmt(parse_assign(m))
		}
		'AugAssign' {
			return Stmt(parse_aug_assign(m))
		}
		'AnnAssign' {
			return Stmt(parse_ann_assign(m))
		}
		'For' {
			return Stmt(parse_for(m))
		}
		'AsyncFor' {
			return Stmt(parse_async_for(m))
		}
		'While' {
			return Stmt(parse_while(m))
		}
		'If' {
			return Stmt(parse_if(m))
		}
		'With' {
			return Stmt(parse_with(m))
		}
		'AsyncWith' {
			return Stmt(parse_async_with(m))
		}
		'Raise' {
			return Stmt(parse_raise(m))
		}
		'Try' {
			return Stmt(parse_try(m))
		}
		'Assert' {
			return Stmt(parse_assert(m))
		}
		'Import' {
			return Stmt(parse_import(m))
		}
		'ImportFrom' {
			return Stmt(parse_import_from(m))
		}
		'Global' {
			return Stmt(parse_global(m))
		}
		'Nonlocal' {
			return Stmt(parse_nonlocal(m))
		}
		'Expr' {
			return Stmt(parse_expr_stmt(m))
		}
		'Pass' {
			return Stmt(Pass{
				loc: parse_location(m)
			})
		}
		'Break' {
			return Stmt(Break{
				loc: parse_location(m)
			})
		}
		'Continue' {
			return Stmt(Continue{
				loc: parse_location(m)
			})
		}
		else {
			return none
		}
	}
}

// Parse an expression node
fn parse_expr(m map[string]json2.Any) ?Expr {
	node_type := m['_type'] or { return none }.str()
	match node_type {
		'Constant' { return Expr(parse_constant(m)) }
		'Name' { return Expr(parse_name(m)) }
		'BinOp' { return Expr(parse_binop(m)) }
		'UnaryOp' { return Expr(parse_unaryop(m)) }
		'BoolOp' { return Expr(parse_boolop(m)) }
		'Compare' { return Expr(parse_compare(m)) }
		'Call' { return Expr(parse_call(m)) }
		'Attribute' { return Expr(parse_attribute(m)) }
		'Subscript' { return Expr(parse_subscript(m)) }
		'Slice' { return Expr(parse_slice(m)) }
		'List' { return Expr(parse_list(m)) }
		'Tuple' { return Expr(parse_tuple(m)) }
		'Dict' { return Expr(parse_dict(m)) }
		'Set' { return Expr(parse_set(m)) }
		'IfExp' { return Expr(parse_ifexp(m)) }
		'Lambda' { return Expr(parse_lambda(m)) }
		'ListComp' { return Expr(parse_list_comp(m)) }
		'SetComp' { return Expr(parse_set_comp(m)) }
		'DictComp' { return Expr(parse_dict_comp(m)) }
		'GeneratorExp' { return Expr(parse_generator_exp(m)) }
		'Await' { return Expr(parse_await(m)) }
		'Yield' { return Expr(parse_yield(m)) }
		'YieldFrom' { return Expr(parse_yield_from(m)) }
		'FormattedValue' { return Expr(parse_formatted_value(m)) }
		'JoinedStr' { return Expr(parse_joined_str(m)) }
		'NamedExpr' { return Expr(parse_named_expr(m)) }
		'Starred' { return Expr(parse_starred(m)) }
		else { return none }
	}
}

// Parse FunctionDef
fn parse_function_def(m map[string]json2.Any) FunctionDef {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut decorators := []Expr{}
	if raw_decs := m['decorator_list'] {
		for item in raw_decs.as_array() {
			if expr := parse_expr(item.as_map()) {
				decorators << expr
			}
		}
	}
	mut mutable_vars := []string{}
	if raw_vars := m['mutable_vars'] {
		for item in raw_vars.as_array() {
			mutable_vars << item.str()
		}
	}
	return FunctionDef{
		name:            m['name'] or { json2.Any('') }.str()
		args:            parse_arguments(m['args'] or { json2.Any(map[string]json2.Any{}) })
		body:            body
		decorator_list:  decorators
		returns:         parse_optional_expr(m['returns'] or { json2.Any(json2.Null{}) })
		type_comment:    parse_optional_string(m['type_comment'] or { json2.Any(json2.Null{}) })
		loc:             parse_location(m)
		is_generator:    m['is_generator'] or { json2.Any(false) }.bool()
		is_void:         m['is_void'] or { json2.Any(false) }.bool()
		mutable_vars:    mutable_vars
		is_class_method: m['is_class_method'] or { json2.Any(false) }.bool()
		class_name:      m['class_name'] or { json2.Any('') }.str()
	}
}

// Parse AsyncFunctionDef
fn parse_async_function_def(m map[string]json2.Any) AsyncFunctionDef {
	fd := parse_function_def(m)
	return AsyncFunctionDef{
		name:            fd.name
		args:            fd.args
		body:            fd.body
		decorator_list:  fd.decorator_list
		returns:         fd.returns
		type_comment:    fd.type_comment
		loc:             fd.loc
		is_generator:    fd.is_generator
		is_void:         fd.is_void
		mutable_vars:    fd.mutable_vars
		is_class_method: fd.is_class_method
		class_name:      fd.class_name
	}
}

// Parse ClassDef
fn parse_class_def(m map[string]json2.Any) ClassDef {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut bases := []Expr{}
	if raw_bases := m['bases'] {
		for item in raw_bases.as_array() {
			if expr := parse_expr(item.as_map()) {
				bases << expr
			}
		}
	}
	mut keywords := []Keyword{}
	if raw_kws := m['keywords'] {
		for item in raw_kws.as_array() {
			keywords << parse_keyword(item.as_map())
		}
	}
	mut decorators := []Expr{}
	if raw_decs := m['decorator_list'] {
		for item in raw_decs.as_array() {
			if expr := parse_expr(item.as_map()) {
				decorators << expr
			}
		}
	}
	mut declarations := map[string]string{}
	if raw_decls := m['declarations'] {
		raw_map := raw_decls.as_map()
		for key, val in raw_map {
			declarations[key] = val.str()
		}
	}
	return ClassDef{
		name:           m['name'] or { json2.Any('') }.str()
		bases:          bases
		keywords:       keywords
		body:           body
		decorator_list: decorators
		loc:            parse_location(m)
		declarations:   declarations
	}
}

// Parse Arguments
fn parse_arguments(raw json2.Any) Arguments {
	m := raw.as_map()
	mut args := []Arg{}
	if raw_args := m['args'] {
		for item in raw_args.as_array() {
			args << parse_arg(item.as_map())
		}
	}
	mut posonlyargs := []Arg{}
	if raw_pos := m['posonlyargs'] {
		for item in raw_pos.as_array() {
			posonlyargs << parse_arg(item.as_map())
		}
	}
	mut kwonlyargs := []Arg{}
	if raw_kw := m['kwonlyargs'] {
		for item in raw_kw.as_array() {
			kwonlyargs << parse_arg(item.as_map())
		}
	}
	mut defaults := []Expr{}
	if raw_defs := m['defaults'] {
		for item in raw_defs.as_array() {
			if expr := parse_expr(item.as_map()) {
				defaults << expr
			}
		}
	}
	mut kw_defaults := []?Expr{}
	if raw_kw_defs := m['kw_defaults'] {
		for item in raw_kw_defs.as_array() {
			kw_defaults << parse_optional_expr(item)
		}
	}
	return Arguments{
		posonlyargs: posonlyargs
		args:        args
		vararg:      parse_optional_arg(m['vararg'] or { json2.Any(json2.Null{}) })
		kwonlyargs:  kwonlyargs
		kw_defaults: kw_defaults
		kwarg:       parse_optional_arg(m['kwarg'] or { json2.Any(json2.Null{}) })
		defaults:    defaults
	}
}

// Parse Arg
fn parse_arg(m map[string]json2.Any) Arg {
	return Arg{
		arg:          m['arg'] or { json2.Any('') }.str()
		annotation:   parse_optional_expr(m['annotation'] or { json2.Any(json2.Null{}) })
		type_comment: parse_optional_string(m['type_comment'] or { json2.Any(json2.Null{}) })
		loc:          parse_location(m)
	}
}

fn parse_optional_arg(raw json2.Any) ?Arg {
	if raw is json2.Null {
		return none
	}
	m := raw.as_map()
	if m.len == 0 {
		return none
	}
	return parse_arg(m)
}

// Parse Keyword
fn parse_keyword(m map[string]json2.Any) Keyword {
	return Keyword{
		arg:   parse_optional_string(m['arg'] or { json2.Any(json2.Null{}) })
		value: parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:   parse_location(m)
	}
}

// Parse Return
fn parse_return(m map[string]json2.Any) Return {
	return Return{
		value: parse_optional_expr(m['value'] or { json2.Any(json2.Null{}) })
		loc:   parse_location(m)
	}
}

// Parse Delete
fn parse_delete(m map[string]json2.Any) Delete {
	mut targets := []Expr{}
	if raw_targets := m['targets'] {
		for item in raw_targets.as_array() {
			if expr := parse_expr(item.as_map()) {
				targets << expr
			}
		}
	}
	return Delete{
		targets: targets
		loc:     parse_location(m)
	}
}

// Parse Assign
fn parse_assign(m map[string]json2.Any) Assign {
	mut targets := []Expr{}
	if raw_targets := m['targets'] {
		for item in raw_targets.as_array() {
			if expr := parse_expr(item.as_map()) {
				targets << expr
			}
		}
	}
	mut redefined := []string{}
	if raw_redef := m['redefined_targets'] {
		for item in raw_redef.as_array() {
			redefined << item.str()
		}
	}
	return Assign{
		targets:           targets
		value:             parse_expr(m['value'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		type_comment:      parse_optional_string(m['type_comment'] or { json2.Any(json2.Null{}) })
		loc:               parse_location(m)
		redefined_targets: redefined
	}
}

// Parse AugAssign
fn parse_aug_assign(m map[string]json2.Any) AugAssign {
	return AugAssign{
		target: parse_expr(m['target'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		op:     parse_operator(m['op'].as_map())
		value:  parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:    parse_location(m)
	}
}

// Parse AnnAssign
fn parse_ann_assign(m map[string]json2.Any) AnnAssign {
	return AnnAssign{
		target:     parse_expr(m['target'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		annotation: parse_expr(m['annotation'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		value:      parse_optional_expr(m['value'] or { json2.Any(json2.Null{}) })
		simple:     m['simple'] or { json2.Any(0) }.int()
		loc:        parse_location(m)
	}
}

// Parse For
fn parse_for(m map[string]json2.Any) For {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut orelse := []Stmt{}
	if raw_else := m['orelse'] {
		for item in raw_else.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				orelse << stmt
			}
		}
	}
	return For{
		target:       parse_expr(m['target'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		iter:         parse_expr(m['iter'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		body:         body
		orelse:       orelse
		type_comment: parse_optional_string(m['type_comment'] or { json2.Any(json2.Null{}) })
		loc:          parse_location(m)
		level:        m['level'] or { json2.Any(0) }.int()
	}
}

// Parse AsyncFor
fn parse_async_for(m map[string]json2.Any) AsyncFor {
	f := parse_for(m)
	return AsyncFor{
		target:       f.target
		iter:         f.iter
		body:         f.body
		orelse:       f.orelse
		type_comment: f.type_comment
		loc:          f.loc
		level:        f.level
	}
}

// Parse While
fn parse_while(m map[string]json2.Any) While {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut orelse := []Stmt{}
	if raw_else := m['orelse'] {
		for item in raw_else.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				orelse << stmt
			}
		}
	}
	return While{
		test:   parse_expr(m['test'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		body:   body
		orelse: orelse
		loc:    parse_location(m)
		level:  m['level'] or { json2.Any(0) }.int()
	}
}

// Parse If
fn parse_if(m map[string]json2.Any) If {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut orelse := []Stmt{}
	if raw_else := m['orelse'] {
		for item in raw_else.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				orelse << stmt
			}
		}
	}
	return If{
		test:   parse_expr(m['test'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		body:   body
		orelse: orelse
		loc:    parse_location(m)
		level:  m['level'] or { json2.Any(0) }.int()
	}
}

// Parse With
fn parse_with(m map[string]json2.Any) With {
	mut items := []WithItem{}
	if raw_items := m['items'] {
		for item in raw_items.as_array() {
			items << parse_with_item(item.as_map())
		}
	}
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	return With{
		items:        items
		body:         body
		type_comment: parse_optional_string(m['type_comment'] or { json2.Any(json2.Null{}) })
		loc:          parse_location(m)
	}
}

fn parse_with_item(m map[string]json2.Any) WithItem {
	return WithItem{
		context_expr:  parse_expr(m['context_expr'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		optional_vars: parse_optional_expr(m['optional_vars'] or { json2.Any(json2.Null{}) })
	}
}

// Parse AsyncWith
fn parse_async_with(m map[string]json2.Any) AsyncWith {
	w := parse_with(m)
	return AsyncWith{
		items:        w.items
		body:         w.body
		type_comment: w.type_comment
		loc:          w.loc
	}
}

// Parse Raise
fn parse_raise(m map[string]json2.Any) Raise {
	return Raise{
		exc:   parse_optional_expr(m['exc'] or { json2.Any(json2.Null{}) })
		cause: parse_optional_expr(m['cause'] or { json2.Any(json2.Null{}) })
		loc:   parse_location(m)
	}
}

// Parse Try
fn parse_try(m map[string]json2.Any) Try {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	mut handlers := []ExceptHandler{}
	if raw_handlers := m['handlers'] {
		for item in raw_handlers.as_array() {
			handlers << parse_except_handler(item.as_map())
		}
	}
	mut orelse := []Stmt{}
	if raw_else := m['orelse'] {
		for item in raw_else.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				orelse << stmt
			}
		}
	}
	mut finalbody := []Stmt{}
	if raw_final := m['finalbody'] {
		for item in raw_final.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				finalbody << stmt
			}
		}
	}
	return Try{
		body:      body
		handlers:  handlers
		orelse:    orelse
		finalbody: finalbody
		loc:       parse_location(m)
	}
}

fn parse_except_handler(m map[string]json2.Any) ExceptHandler {
	mut body := []Stmt{}
	if raw_body := m['body'] {
		for item in raw_body.as_array() {
			if stmt := parse_stmt(item.as_map()) {
				body << stmt
			}
		}
	}
	return ExceptHandler{
		typ:  parse_optional_expr(m['type'] or { json2.Any(json2.Null{}) })
		name: parse_optional_string(m['name'] or { json2.Any(json2.Null{}) })
		body: body
		loc:  parse_location(m)
	}
}

// Parse Assert
fn parse_assert(m map[string]json2.Any) Assert {
	return Assert{
		test: parse_expr(m['test'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		msg:  parse_optional_expr(m['msg'] or { json2.Any(json2.Null{}) })
		loc:  parse_location(m)
	}
}

// Parse Import
fn parse_import(m map[string]json2.Any) Import {
	mut names := []Alias{}
	if raw_names := m['names'] {
		for item in raw_names.as_array() {
			names << parse_alias(item.as_map())
		}
	}
	return Import{
		names: names
		loc:   parse_location(m)
	}
}

// Parse ImportFrom
fn parse_import_from(m map[string]json2.Any) ImportFrom {
	mut names := []Alias{}
	if raw_names := m['names'] {
		for item in raw_names.as_array() {
			names << parse_alias(item.as_map())
		}
	}
	return ImportFrom{
		mod:   parse_optional_string(m['module'] or { json2.Any(json2.Null{}) })
		names: names
		level: m['level'] or { json2.Any(0) }.int()
		loc:   parse_location(m)
	}
}

fn parse_alias(m map[string]json2.Any) Alias {
	return Alias{
		name:   m['name'] or { json2.Any('') }.str()
		asname: parse_optional_string(m['asname'] or { json2.Any(json2.Null{}) })
		loc:    parse_location(m)
	}
}

// Parse Global
fn parse_global(m map[string]json2.Any) Global {
	mut names := []string{}
	if raw_names := m['names'] {
		for item in raw_names.as_array() {
			names << item.str()
		}
	}
	return Global{
		names: names
		loc:   parse_location(m)
	}
}

// Parse Nonlocal
fn parse_nonlocal(m map[string]json2.Any) Nonlocal {
	mut names := []string{}
	if raw_names := m['names'] {
		for item in raw_names.as_array() {
			names << item.str()
		}
	}
	return Nonlocal{
		names: names
		loc:   parse_location(m)
	}
}

// Parse ExprStmt
fn parse_expr_stmt(m map[string]json2.Any) ExprStmt {
	return ExprStmt{
		value: parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:   parse_location(m)
	}
}

// Parse Constant
fn parse_constant(m map[string]json2.Any) Constant {
	raw_val := m['value'] or { json2.Any(json2.Null{}) }
	value := parse_constant_value(raw_val)
	return Constant{
		value:        value
		kind:         parse_optional_string(m['kind'] or { json2.Any(json2.Null{}) })
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

fn parse_constant_value(raw json2.Any) ConstantValue {
	if raw is json2.Null {
		return NoneValue{}
	}
	if raw is map[string]json2.Any {
		m := raw as map[string]json2.Any
		if typ := m['_type'] {
			typ_str := typ.str()
			if typ_str == 'Ellipsis' {
				return EllipsisValue{}
			}
			if typ_str == 'bytes' {
				mut data := []u8{}
				if val := m['value'] {
					for b in val.as_array() {
						data << u8(b.int())
					}
				}
				return BytesValue{
					data: data
				}
			}
		}
	}
	match raw {
		bool {
			return ConstantValue(raw as bool)
		}
		i64 {
			val := raw as i64
			if val >= i64(-2147483647) - 1 && val <= i64(2147483647) {
				return ConstantValue(int(val))
			}
			return ConstantValue(val)
		}
		f64 {
			val := raw as f64
			int_val := i64(val)
			if f64(int_val) == val && int_val >= i64(-2147483647) - 1 && int_val <= i64(2147483647) {
				return ConstantValue(int(int_val))
			}
			return ConstantValue(val)
		}
		string {
			return ConstantValue(raw as string)
		}
		else {
			return NoneValue{}
		}
	}
}

// Parse Name
fn parse_name(m map[string]json2.Any) Name {
	return Name{
		id:           m['id'] or { json2.Any('') }.str()
		ctx:          parse_context(m['ctx'].as_map())
		loc:          parse_location(m)
		is_mutable:   m['is_mutable'] or { json2.Any(false) }.bool()
		v_annotation: parse_type_annotation(m)
	}
}

// Parse context
fn parse_context(m map[string]json2.Any) ExprContext {
	ctx_type := m['_type'] or { json2.Any('Load') }.str()
	return match ctx_type {
		'Store' { ExprContext(Store{}) }
		'Del' { ExprContext(Del{}) }
		else { ExprContext(Load{}) }
	}
}

// Parse BinOp
fn parse_binop(m map[string]json2.Any) BinOp {
	return BinOp{
		left:         parse_expr(m['left'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		op:           parse_operator(m['op'].as_map())
		right:        parse_expr(m['right'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse Operator
fn parse_operator(m map[string]json2.Any) Operator {
	op_type := m['_type'] or { json2.Any('Add') }.str()
	return match op_type {
		'Sub' { Operator(Sub{}) }
		'Mult' { Operator(Mult{}) }
		'MatMult' { Operator(MatMult{}) }
		'Div' { Operator(Div{}) }
		'Mod' { Operator(Mod{}) }
		'Pow' { Operator(Pow{}) }
		'LShift' { Operator(LShift{}) }
		'RShift' { Operator(RShift{}) }
		'BitOr' { Operator(BitOr{}) }
		'BitXor' { Operator(BitXor{}) }
		'BitAnd' { Operator(BitAnd{}) }
		'FloorDiv' { Operator(FloorDiv{}) }
		else { Operator(Add{}) }
	}
}

// Parse UnaryOp
fn parse_unaryop(m map[string]json2.Any) UnaryOp {
	return UnaryOp{
		op:           parse_unary_operator(m['op'].as_map())
		operand:      parse_expr(m['operand'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

fn parse_unary_operator(m map[string]json2.Any) UnaryOperator {
	op_type := m['_type'] or { json2.Any('Not') }.str()
	return match op_type {
		'Invert' { UnaryOperator(Invert{}) }
		'UAdd' { UnaryOperator(UAdd{}) }
		'USub' { UnaryOperator(USub{}) }
		else { UnaryOperator(Not{}) }
	}
}

// Parse BoolOp
fn parse_boolop(m map[string]json2.Any) BoolOp {
	mut values := []Expr{}
	if raw_values := m['values'] {
		for item in raw_values.as_array() {
			if expr := parse_expr(item.as_map()) {
				values << expr
			}
		}
	}
	return BoolOp{
		op:           parse_bool_operator(m['op'].as_map())
		values:       values
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

fn parse_bool_operator(m map[string]json2.Any) BoolOperator {
	op_type := m['_type'] or { json2.Any('And') }.str()
	return match op_type {
		'Or' { BoolOperator(Or{}) }
		else { BoolOperator(And{}) }
	}
}

// Parse Compare
fn parse_compare(m map[string]json2.Any) Compare {
	mut ops := []CmpOp{}
	if raw_ops := m['ops'] {
		for item in raw_ops.as_array() {
			ops << parse_cmp_op(item.as_map())
		}
	}
	mut comparators := []Expr{}
	if raw_comps := m['comparators'] {
		for item in raw_comps.as_array() {
			if expr := parse_expr(item.as_map()) {
				comparators << expr
			}
		}
	}
	return Compare{
		left:         parse_expr(m['left'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		ops:          ops
		comparators:  comparators
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

fn parse_cmp_op(m map[string]json2.Any) CmpOp {
	op_type := m['_type'] or { json2.Any('Eq') }.str()
	return match op_type {
		'NotEq' { CmpOp(NotEq{}) }
		'Lt' { CmpOp(Lt{}) }
		'LtE' { CmpOp(LtE{}) }
		'Gt' { CmpOp(Gt{}) }
		'GtE' { CmpOp(GtE{}) }
		'Is' { CmpOp(Is{}) }
		'IsNot' { CmpOp(IsNot{}) }
		'In' { CmpOp(In{}) }
		'NotIn' { CmpOp(NotIn{}) }
		else { CmpOp(Eq{}) }
	}
}

// Parse Call
fn parse_call(m map[string]json2.Any) Call {
	mut args := []Expr{}
	if raw_args := m['args'] {
		for item in raw_args.as_array() {
			if expr := parse_expr(item.as_map()) {
				args << expr
			}
		}
	}
	mut keywords := []Keyword{}
	if raw_kws := m['keywords'] {
		for item in raw_kws.as_array() {
			keywords << parse_keyword(item.as_map())
		}
	}
	return Call{
		func:         parse_expr(m['func'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		args:         args
		keywords:     keywords
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse Attribute
fn parse_attribute(m map[string]json2.Any) Attribute {
	return Attribute{
		value:        parse_expr(m['value'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		attr:         m['attr'] or { json2.Any('') }.str()
		ctx:          parse_context(m['ctx'].as_map())
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse Subscript
fn parse_subscript(m map[string]json2.Any) Subscript {
	return Subscript{
		value:         parse_expr(m['value'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		slice:         parse_expr(m['slice'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		ctx:           parse_context(m['ctx'].as_map())
		loc:           parse_location(m)
		v_annotation:  parse_type_annotation(m)
		is_annotation: m['is_annotation'] or { json2.Any(false) }.bool()
	}
}

// Parse Slice
fn parse_slice(m map[string]json2.Any) Slice {
	return Slice{
		lower: parse_optional_expr(m['lower'] or { json2.Any(json2.Null{}) })
		upper: parse_optional_expr(m['upper'] or { json2.Any(json2.Null{}) })
		step:  parse_optional_expr(m['step'] or { json2.Any(json2.Null{}) })
		loc:   parse_location(m)
	}
}

// Parse List
fn parse_list(m map[string]json2.Any) List {
	mut elts := []Expr{}
	if raw_elts := m['elts'] {
		for item in raw_elts.as_array() {
			if expr := parse_expr(item.as_map()) {
				elts << expr
			}
		}
	}
	return List{
		elts:         elts
		ctx:          parse_context(m['ctx'].as_map())
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse Tuple
fn parse_tuple(m map[string]json2.Any) Tuple {
	mut elts := []Expr{}
	if raw_elts := m['elts'] {
		for item in raw_elts.as_array() {
			if expr := parse_expr(item.as_map()) {
				elts << expr
			}
		}
	}
	return Tuple{
		elts:         elts
		ctx:          parse_context(m['ctx'].as_map())
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse Dict
fn parse_dict(m map[string]json2.Any) Dict {
	mut keys := []?Expr{}
	if raw_keys := m['keys'] {
		for item in raw_keys.as_array() {
			keys << parse_optional_expr(item)
		}
	}
	mut values := []Expr{}
	if raw_values := m['values'] {
		for item in raw_values.as_array() {
			if expr := parse_expr(item.as_map()) {
				values << expr
			}
		}
	}
	return Dict{
		keys:         keys
		values:       values
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse Set
fn parse_set(m map[string]json2.Any) Set {
	mut elts := []Expr{}
	if raw_elts := m['elts'] {
		for item in raw_elts.as_array() {
			if expr := parse_expr(item.as_map()) {
				elts << expr
			}
		}
	}
	return Set{
		elts:         elts
		loc:          parse_location(m)
		v_annotation: parse_type_annotation(m)
	}
}

// Parse IfExp
fn parse_ifexp(m map[string]json2.Any) IfExp {
	return IfExp{
		test:   parse_expr(m['test'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		body:   parse_expr(m['body'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		orelse: parse_expr(m['orelse'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:    parse_location(m)
	}
}

// Parse Lambda
fn parse_lambda(m map[string]json2.Any) Lambda {
	return Lambda{
		args: parse_arguments(m['args'] or { json2.Any(map[string]json2.Any{}) })
		body: parse_expr(m['body'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:  parse_location(m)
	}
}

// Parse ListComp
fn parse_list_comp(m map[string]json2.Any) ListComp {
	mut generators := []Comprehension{}
	if raw_gens := m['generators'] {
		for item in raw_gens.as_array() {
			generators << parse_comprehension(item.as_map())
		}
	}
	return ListComp{
		elt:        parse_expr(m['elt'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		generators: generators
		loc:        parse_location(m)
	}
}

// Parse SetComp
fn parse_set_comp(m map[string]json2.Any) SetComp {
	mut generators := []Comprehension{}
	if raw_gens := m['generators'] {
		for item in raw_gens.as_array() {
			generators << parse_comprehension(item.as_map())
		}
	}
	return SetComp{
		elt:        parse_expr(m['elt'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		generators: generators
		loc:        parse_location(m)
	}
}

// Parse DictComp
fn parse_dict_comp(m map[string]json2.Any) DictComp {
	mut generators := []Comprehension{}
	if raw_gens := m['generators'] {
		for item in raw_gens.as_array() {
			generators << parse_comprehension(item.as_map())
		}
	}
	return DictComp{
		key:        parse_expr(m['key'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		value:      parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		generators: generators
		loc:        parse_location(m)
	}
}

// Parse GeneratorExp
fn parse_generator_exp(m map[string]json2.Any) GeneratorExp {
	mut generators := []Comprehension{}
	if raw_gens := m['generators'] {
		for item in raw_gens.as_array() {
			generators << parse_comprehension(item.as_map())
		}
	}
	return GeneratorExp{
		elt:        parse_expr(m['elt'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		generators: generators
		loc:        parse_location(m)
	}
}

fn parse_comprehension(m map[string]json2.Any) Comprehension {
	mut ifs := []Expr{}
	if raw_ifs := m['ifs'] {
		for item in raw_ifs.as_array() {
			if expr := parse_expr(item.as_map()) {
				ifs << expr
			}
		}
	}
	return Comprehension{
		target:   parse_expr(m['target'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		iter:     parse_expr(m['iter'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		ifs:      ifs
		is_async: m['is_async'] or { json2.Any(false) }.bool()
	}
}

// Parse Await
fn parse_await(m map[string]json2.Any) Await {
	return Await{
		value: parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:   parse_location(m)
	}
}

// Parse Yield
fn parse_yield(m map[string]json2.Any) Yield {
	return Yield{
		value: parse_optional_expr(m['value'] or { json2.Any(json2.Null{}) })
		loc:   parse_location(m)
	}
}

// Parse YieldFrom
fn parse_yield_from(m map[string]json2.Any) YieldFrom {
	return YieldFrom{
		value: parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:   parse_location(m)
	}
}

// Parse FormattedValue
fn parse_formatted_value(m map[string]json2.Any) FormattedValue {
	return FormattedValue{
		value:       parse_expr(m['value'].as_map()) or {
			Expr(Constant{
				value: NoneValue{}
			})
		}
		conversion:  m['conversion'] or { json2.Any(-1) }.int()
		format_spec: parse_optional_expr(m['format_spec'] or { json2.Any(json2.Null{}) })
		loc:         parse_location(m)
	}
}

// Parse JoinedStr
fn parse_joined_str(m map[string]json2.Any) JoinedStr {
	mut values := []Expr{}
	if raw_values := m['values'] {
		for item in raw_values.as_array() {
			if expr := parse_expr(item.as_map()) {
				values << expr
			}
		}
	}
	return JoinedStr{
		values: values
		loc:    parse_location(m)
	}
}

// Parse NamedExpr
fn parse_named_expr(m map[string]json2.Any) NamedExpr {
	return NamedExpr{
		target: parse_expr(m['target'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		value:  parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		loc:    parse_location(m)
	}
}

// Parse Starred
fn parse_starred(m map[string]json2.Any) Starred {
	return Starred{
		value: parse_expr(m['value'].as_map()) or { Expr(Constant{
			value: NoneValue{}
		}) }
		ctx:   parse_context(m['ctx'].as_map())
		loc:   parse_location(m)
	}
}

// Helper functions
fn parse_optional_expr(raw json2.Any) ?Expr {
	if raw is json2.Null {
		return none
	}
	m := raw.as_map()
	if m.len == 0 {
		return none
	}
	return parse_expr(m)
}

fn parse_optional_string(raw json2.Any) ?string {
	if raw is json2.Null {
		return none
	}
	s := raw.str()
	if s.len == 0 || s == 'null' {
		return none
	}
	return s
}
