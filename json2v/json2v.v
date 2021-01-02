module main

import os
import v.ast
//import v.checker
import v.fmt
//import v.pref
import v.table
import v.token
import x.json2

const (
	operators = {'LShift': token.Kind.left_shift
				 'RShift': token.Kind.right_shift
				 'Eq': token.Kind.eq
				 'NotEq': token.Kind.ne
				 'Lt': token.Kind.lt
				 'LtE': token.Kind.le
				 'Gt': token.Kind.gt
				 'GtE': token.Kind.ge
				 'Is': token.Kind.eq
				 'IsNot': token.Kind.ne
				 'In': token.Kind.key_in
				 'NotIn': token.Kind.not_in
				 'Add': token.Kind.plus
				 'Sub': token.Kind.minus
				 'Mult': token.Kind.mul
				 'Div': token.Kind.div
				 'Mod': token.Kind.mod
				 'BitOr': token.Kind.pipe
				 'BitXor': token.Kind.xor
				 'BitAnd': token.Kind.amp}
)

[inline]
fn is_resolved_type(typ table.Type) bool {
	return typ !in [table.void_type, table.any_type]
}

fn (mut t Transpiler) fix_name(name string) string {
	mut name_ := t.current_scope.redirect(name)

	if name_ in token.token_str || name_ in table.builtin_type_names {
		name_ = '${name_}_'
	}

	println(@FN + ': $name_')
	return name_
}

struct Transpiler {
mut:
	tbl &table.Table
	file &ast.File
	const_decl &ast.ConstDecl = voidptr(0)
	current_scope &Scope = &Scope{}
	ast_scope &ast.Scope = &ast.Scope{parent: 0}
}

[inline]
fn (mut t Transpiler) is_at_top() bool {
	return isnil(t.current_scope.parent)
}

[inline]
fn (mut t Transpiler) scope_up() {
	t.current_scope = t.current_scope.get_parent()
}

[inline]
fn (mut t Transpiler) scope_down() {
	t.current_scope = t.current_scope.new_child()
}

fn translate_op(op json2.Any) token.Kind {
	key := op.as_map()['@type'].str()
	if key in operators {
		return operators[key]
	}
	return token.Kind.unknown
}

fn (mut t Transpiler) translate_annotation(ann json2.Any) table.Type {
	map_ann := ann.as_map()
	match map_ann['@type'].str() {
		'Name' {
			return match map_ann['id'].str() {
				'str' {
					table.string_type
				}
				'bytes', 'bytearray' {
					table.new_type(t.tbl.find_or_register_array(table.byte_type, 1))
				}
				else {
					table.any_type
				}
			}
		}
		'' {
			table.void_type  // no info
		}
		else {
			eprintln('unhandled type ${map_ann["@type"].str()}')
		}
	}
	return table.any_type
}

fn (mut t Transpiler) get_type(expr ast.Expr) table.Type {
	match expr {
		ast.Ident {
			info := t.current_scope.get(expr.name) or { return table.any_type }
			$if debug {
				println('ident: $expr.name has type ${t.tbl.get_type_name(info.typ)}')
			}
			return info.typ
		}
		ast.SelectorExpr {
			name := '${(expr.expr as ast.Ident).name}.${expr.field_name}'
			info := t.current_scope.get(name) or { return table.any_type }
			$if debug {
				println('selector: $name has type ${t.tbl.get_type_name(info.typ)}')
			}
			return info.typ
		}
		ast.IntegerLiteral {
			return table.int_type
		}
		else {}
	}
	return table.any_type
}

fn visit_constant(node json2.Any) ast.Expr {
	map_node := node.as_map()
	match map_node['@constant_type'].str() {
		'str' {
			return ast.StringLiteral{val: map_node['value'] as string}
		}
		'bytes' {
			mut chars := []ast.Expr{}
			for c in map_node['value'].arr() {
				chars << ast.CharLiteral{val: c as string}
			}

			return ast.ArrayInit{exprs: chars elem_type: table.rune_type}
		}
		'int' {
			return ast.IntegerLiteral{val: map_node['value'].str()}
		}
		else {
			eprintln('unhandled constant type')
			return ast.None{}
		}
	}
}

fn (mut t Transpiler) visit_expr(node json2.Any) ast.Expr {
	map_node := node.as_map()
	match map_node['@type'].str() {
		'Call' {
			return t.visit_call(node)
		}
		'Constant' {
			return visit_constant(node)
		}
		'Name' {
			name := t.fix_name(map_node['id'].str())
			if '.' !in name {
				return ast.Ident{name: name scope: 0 info: ast.IdentVar{}}
			}
			return ast.SelectorExpr{expr: ast.Ident{name: name.split('.')[0] scope: 0 info: ast.IdentVar{}} field_name: name.split('.')[1] scope: 0}
		}
		'Tuple' {
			mut exprs := []ast.Expr{}
			for expr in map_node['elts'].arr() {
				exprs << t.visit_expr(expr)
			}
			return ast.ArrayInit{exprs: exprs elem_type: table.void_type}
		}
		'BinOp' {
			return ast.InfixExpr{op: translate_op(map_node['op'])
								 left: t.visit_expr(map_node['left'])
								 right: t.visit_expr(map_node['right'])}
		}
		'Compare' {
			mut exprs := []ast.Expr{}
			exprs << t.visit_expr(map_node['left'])
			for expr in map_node['comparators'].arr() {
				exprs << t.visit_expr(expr)
			}

			mut cmps := []ast.InfixExpr{}
			for i, op in map_node['ops'].arr() {
				cmps << ast.InfixExpr{op: translate_op(op) left: exprs[i] right: exprs[i+1]} 
			}

			for cmps.len > 1 {
				cmps.prepend(ast.InfixExpr{op: token.Kind.and left: ast.ParExpr{expr: cmps[0]} right: ast.ParExpr{expr: cmps[1]}})
				cmps.delete(1)
				cmps.delete(1)
			}
			return cmps[0]
		}
		'Subscript' {
			value := t.visit_expr(map_node['value'])
			slice := t.visit_expr(map_node['slice'])
			return ast.IndexExpr{left: value index: slice}
		}
		else {
			eprintln('unhandled expr type ${map_node["@type"]}')
			return ast.None{}
		}
	}
}

fn (mut t Transpiler) visit_ast(node json2.Any) []ast.Stmt {
	map_node := node.as_map()
	mut stmts := []ast.Stmt{}
	match map_node['@type'].str() {
		'FunctionDef' {
			t.scope_down()
			$if debug {
				println('====')
			}
			name := t.fix_name(map_node['name'].str())
			mut params := []table.Param{}
			mut body_stmts := []ast.Stmt{}
			mut return_type := t.translate_annotation(map_node['returns'])

			map_args := map_node['args'].as_map()
			arr_posonlyargs := map_args['posonlyargs'].arr()
			arr_args := map_args['args'].arr()
			arr_kwonlyargs := map_args['kwonlyargs'].arr()
			arr_defaults := map_args['defaults'].arr()
			mut needs_struct := arr_kwonlyargs.len != 0 || arr_defaults.len != 0
			mut st := ast.StructDecl{name: '${name}Options'}
			for i, arg in arr_posonlyargs {
				map_arg := arg.as_map()
				arg_name := t.fix_name(map_arg['arg'].str())
				mut arg_type := t.translate_annotation(map_arg['annotation'])
				default_index := arr_defaults.len - arr_args.len - arr_posonlyargs.len + i
				if default_index >= 0 { // has default
					default_expr := t.visit_expr(arr_defaults[default_index])
					st.fields << ast.StructField{name: arg_name typ: arg_type has_default_expr: true default_expr: default_expr}
					if arg_type in [table.void_type, table.any_type] {
						arg_type = t.get_type(default_expr)
					}
					t.current_scope.redirects[arg_name] = '${name}_options.$arg_name'
					t.current_scope.add('${name}_options.$arg_name', &ast.IdentVar{typ: arg_type})
				} else {
					params << table.Param{name: arg_name, typ: arg_type}
					t.current_scope.add(arg_name, &ast.IdentVar{typ: arg_type})
				}
			}

			for i, arg in arr_args {
				map_arg := arg.as_map()
				arg_name := t.fix_name(map_arg['arg'].str())
				mut arg_type := t.translate_annotation(map_arg['annotation'])
				default_index := arr_defaults.len - arr_args.len + i
				if default_index >= 0 { // has default
					default_expr := t.visit_expr(arr_defaults[default_index])
					st.fields << ast.StructField{name: arg_name typ: arg_type has_default_expr: true default_expr: default_expr}
					if arg_type in [table.void_type, table.any_type] {
						arg_type = t.get_type(default_expr)
					}
					t.current_scope.redirects[arg_name] = '${name}_options.$arg_name'
					t.current_scope.add('${name}_options.$arg_name', &ast.IdentVar{typ: arg_type})
				} else {
					params << table.Param{name: arg_name, typ: arg_type}
					t.current_scope.add(arg_name, &ast.IdentVar{typ: arg_type})
				}
			}

			if needs_struct {
				stmts << st
				params << table.Param{name: '${name}_options' typ: t.tbl.add_placeholder_type('${name}Options', table.Language.v)}
			}

			for node2 in map_node['body'].arr() {
				for stmt in t.visit_ast(node2) {
					body_stmts << stmt
					if stmt is ast.Return {
						if return_type !in [table.void_type, table.any_type] || stmt.exprs.len == 0 {
							continue
						}

						return_type = t.get_type(stmt.exprs[0])
					}
				}
			}

			if body_stmts.len > 0 {
				first := body_stmts[0]
				if first is ast.ExprStmt {
					first_expr := first.expr
					if first_expr is ast.StringLiteral {
						stmts << ast.ExprStmt{expr: ast.Comment{text: first_expr.val}}
						body_stmts.delete(0)
					}
				}
			}

			if return_type == 0 {
				return_type = table.void_type
			}

			$if debug {
				println('==fn $name ${t.tbl.get_type_name(return_type)}==')
			}
			stmts << ast.FnDecl{return_type: return_type
								stmts: body_stmts
								name: name
								scope: t.ast_scope
								params: params}
			
			t.scope_up()
		}
		'Expr' {
			stmts << ast.ExprStmt{expr: t.visit_expr(map_node['value'])}
		}
		'Assert' {
			stmts << ast.AssertStmt{expr: t.visit_expr(map_node['test'])}
		}
		'Import' {
			for imp in map_node['names'].arr() {
				map_imp := imp.as_map()
				if map_imp['asname'] is json2.Null {
					t.file.imports << ast.Import{mod: map_imp['name'].str() alias: map_imp['name'].str()}
				}
				else {
					t.file.imports << ast.Import{mod: map_imp['name'].str() alias: map_imp['asname'].str()}
				}
			}
		}
		'Return' {
			mut exprs := []ast.Expr{}
			mut types := []table.Type{}
			if map_node['value'] !is json2.Null {
				exprs = [t.visit_expr(map_node['value'])]
				types = [t.get_type(exprs[0])]
				println(types)
			}
			stmts << ast.Return{exprs: exprs types: types}
		}
		'Assign' {
			if t.is_at_top() {
				if isnil(t.const_decl) {
					t.const_decl = &ast.ConstDecl{}
					stmts << t.const_decl
				}

				name := t.fix_name(map_node['targets'].arr()[0].as_map()['id'].str())
				field := ast.ConstField{name: name
										expr: t.visit_expr(map_node['value'])}
				t.const_decl.fields << field
				t.current_scope.add(name, &ast.IdentVar{typ: t.get_type(field.expr)})
			} else {
				mut left := []ast.Expr{}
				mut right := []ast.Expr{}
				mut kind := token.Kind.decl_assign

				if map_node['value'].as_map()['@type'].str() == 'Tuple' {
					for expr in map_node['value'].as_map()['elts'].arr() {
						right << t.visit_expr(expr)
					}
				} else {
					right << t.visit_expr(map_node['value'])
				}

				for i, expr in map_node['targets'].arr() {
					e := t.visit_expr(expr)
					mut ident := e as ast.Ident // FIX: assignment on to a function parameter with a default value will break this cast
					typ := t.get_type(right[i])
					iv := ast.IdentVar{typ: typ}
					if !t.current_scope.add(ident.name, &iv) {
						kind = token.Kind.assign
						mut info := t.current_scope.get(ident.name) or { panic('cosmic bit flip') }
						info.is_mut = true
						info.typ = typ
					}
					left << e
				}

				stmts << ast.AssignStmt{left: left right: right op: kind}
			}
		}
		'For' {
			target := t.visit_expr(map_node['target'])
			iter := t.visit_expr(map_node['iter'])
			mut name := '' 

			mut body_stmts := []ast.Stmt{}
			if target is ast.ArrayInit {
				mut ident := ast.Ident{scope: t.ast_scope name: target.exprs.map((it as ast.Ident).name).join('')}
				for i, subtarget in target.exprs {
					left := [subtarget]
					right := [ast.Expr(ast.IndexExpr{left: ident index: ast.IntegerLiteral{val: i.str()}})]
					body_stmts << ast.AssignStmt{left: left op: token.Kind.decl_assign right: right}
				}
				name = ident.name
			}

			for stmt in map_node['body'].arr() {
				body_stmts << t.visit_ast(stmt)
			}

			stmts << ast.ForInStmt{val_var: name cond: iter stmts: body_stmts scope: t.ast_scope}
		}
		'If' {
			cond := t.visit_expr(map_node['test'])

			mut body_stmts := []ast.Stmt{}
			for stmt in map_node['body'].arr() {
				body_stmts << t.visit_ast(stmt)
			}

			mut else_stmts := []ast.Stmt{}
			for stmt in map_node['orelse'].arr() {
				else_stmts << t.visit_ast(stmt)
			}

			if else_stmts.len == 0 {
				stmts << ast.ExprStmt{expr: ast.IfExpr{branches: [ast.IfBranch{cond: cond stmts: body_stmts scope: t.ast_scope}]}}
			} else {
				stmts << ast.ExprStmt{expr: ast.IfExpr{branches: [ast.IfBranch{cond: cond stmts: body_stmts scope: t.ast_scope},
											   					  ast.IfBranch{cond: cond stmts: else_stmts scope: t.ast_scope}]
													   has_else: true}}
			}
		}
		'AugAssign' {  // FIX: needs to set mut
			target := t.visit_expr(map_node['target'])
			value := t.visit_expr(map_node['value'])

			left := [target]
			right := [ast.Expr(ast.InfixExpr{left: target op: translate_op(map_node['op']) right: value})]
			stmts << ast.AssignStmt{left: left right: right op: token.Kind.assign}
		}
		else {
			eprintln('unhandled stmt type ${map_node["@type"]}')
		}
	}
	return stmts
}

/*fn (mut t Transpiler) revisit_stmt(mut stmt ast.Stmt) {
	match stmt {
		ast.FnDecl {
			mut decl := stmt as ast.FnDecl
			for param in decl.params {
				if is_resolved_type(param.typ) {
					continue
				}

				info := t.current_scope.get(param.name) or { continue }
				unsafe { C.memcpy(&param.typ, &info.typ, sizeof(table.Type)) }
			}

			for mut body_stmt in decl.stmts {
				t.revisit_stmt(mut body_stmt)
			}
		}
		ast.AssignStmt {
			mut asgn := stmt as ast.AssignStmt
			if asgn.op == token.Kind.decl_assign {
				mut ident := asgn.left[0] as ast.Ident
				mut identvar := ident.info as ast.IdentVar
				info := t.current_scope.get(ident.name) or { return }
				identvar.is_mut = info.is_mut
			}
		}
		else {}
	}
}*/

fn main() {
	if os.args.len < 3 {
		eprintln('USAGE: ${os.args[0]} <source> <destination>')
		return
	}

	json_source := os.read_file(os.args[1])? 
	json_ast := json2.raw_decode(json_source)?
	map_ast := json_ast.as_map()

	scope := ast.Scope{parent: 0}
	mut file := ast.File{global_scope: &scope scope: &scope}
	mut table := table.new_table()

	mut t := &Transpiler{tbl: table file: &file ast_scope: &scope}

	assert map_ast['@type'].str() == 'Module'
	for node in map_ast['body'].arr() {
		file.stmts << t.visit_ast(node)
	}

	/*for mut stmt in file.stmts {
		t.revisit_stmt(mut stmt)
	}*/

	/*mut checker := checker.new_checker(table, &pref.Preferences{})
	checker.check(file)
	println(checker.errors)
	println(checker.warnings)*/
	os.write_file(os.args[2], fmt.fmt(file, table, false)) 
}