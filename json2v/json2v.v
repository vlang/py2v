module main

import os
import v.ast
import v.fmt
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
				 'BitAnd': token.Kind.and}
)

fn fix_name(name string) string {
	if name in token.token_str || name in table.builtin_type_names {
		return '${name}_'
	}

	if name.is_upper() {
		return name.to_lower()
	}

	return name
}

struct Transpiler {
mut:
	tbl &table.Table
	file &ast.File
	const_decl &ast.ConstDecl = voidptr(0)
	current_scope &Scope = &Scope{}
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
		else {
			eprintln('unhandled type ${map_ann["@type"].str()}')
		}
	}
	return table.any_type
}

fn (mut t Transpiler) get_type(expr ast.Expr) table.Type {
	match expr {
		ast.Ident {
			println(expr.name)
			ident := t.current_scope.get(expr.name) or { return table.void_type }
			return ident.typ
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

			return ast.ArrayInit{exprs: chars}
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
			var := ast.Ident{name: fix_name(map_node['id'].str()) scope: voidptr(0) info: ast.IdentVar{typ: table.void_type}}
			return var
		}
		'Tuple' {
			mut exprs := []ast.Expr{}
			for expr in map_node['elts'].arr() {
				exprs << t.visit_expr(expr)
			}
			return ast.ArrayInit{exprs: exprs}
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
			mut body_stmts := []ast.Stmt{}
			mut return_type := t.translate_annotation(map_node['returns'])

			for node2 in map_node['body'].arr() {
				for stmt in t.visit_ast(node2) {
					body_stmts << stmt
					if stmt is ast.Return {
						if return_type !in [table.void_type, table.any_type] || stmt.exprs.len == 0 {
							continue
						}

						return_type = t.get_type(stmt.exprs[0])
						println('ret $return_type')
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

			println('${map_node['name'].str()} $return_type')
			stmts << ast.FnDecl{return_type: return_type
								stmts: body_stmts
								name: map_node['name'].str()
								scope: voidptr(0)}
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
			if map_node['value'] !is json2.Null {
				exprs = [t.visit_expr(map_node['value'])]
			}
			stmts << ast.Return{exprs: exprs}
		}
		'Assign' {
			if t.is_at_top() {
				if isnil(t.const_decl) {
					t.const_decl = &ast.ConstDecl{}
					stmts << t.const_decl
				}

				field := ast.ConstField{name: fix_name(map_node['targets'].arr()[0].as_map()['id'].str())
										expr: t.visit_expr(map_node['value'])}
				t.const_decl.fields << field
				// t.current_scope.add(field)
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
					mut ident := e as ast.Ident
					mut info := ident.var_info()
					typ := t.get_type(right[i])
					info.typ = typ
					if !t.current_scope.add(ident.name, &info) {
						kind = token.Kind.assign
						mut prev_ident := t.current_scope.get(ident.name) or { panic('cosmic bit flip') }
						prev_ident.is_mut = true
						prev_typ := prev_ident.typ
						if prev_typ != typ && table.void_type !in [typ, prev_typ] {
							eprintln('warn: type mismatch (${t.tbl.type_to_str(prev_typ)} != ${t.tbl.type_to_str(typ)})')
						}
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
				mut ident := ast.Ident{scope: &voidptr(0)}
				for i, subtarget in target.exprs {
					name += (subtarget as ast.Ident).name
					left := [subtarget]
					right := [ast.Expr(ast.IndexExpr{left: &ident index: ast.IntegerLiteral{val: i.str()}})]
					body_stmts << ast.AssignStmt{left: left op: token.Kind.decl_assign right: right}
				}
				ident.name = name
			}

			for stmt in map_node['body'].arr() {
				body_stmts << t.visit_ast(stmt)
			}

			stmts << ast.ForInStmt{val_var: name cond: iter stmts: body_stmts scope: voidptr(0)}
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
				stmts << ast.ExprStmt{expr: ast.IfExpr{branches: [ast.IfBranch{cond: cond stmts: body_stmts scope: &voidptr(0)}]}}
			} else {
				stmts << ast.ExprStmt{expr: ast.IfExpr{branches: [ast.IfBranch{cond: cond stmts: body_stmts scope: &voidptr(0)},
											   					  ast.IfBranch{cond: cond stmts: else_stmts scope: &voidptr(0)}]
													   has_else: true}}
			}
		}
		'AugAssign' {
			target := t.visit_expr(map_node['target'])
			value := t.visit_expr(map_node['value'])

			if target is ast.Ident {
				mut prev_ident := t.current_scope.get(target.name) or { eprintln('error: augassign on undefined variable') return stmts}
				prev_ident.is_mut = true
			}
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

fn main() {
	if os.args.len < 3 {
		eprintln('USAGE: ${os.args[0]} <source> <destination>')
		return
	}

	json_source := os.read_file(os.args[1])? 
	json_ast := json2.raw_decode(json_source)?
	map_ast := json_ast.as_map()

	mut file := ast.File{global_scope: voidptr(0) scope: voidptr(0)}
	mut table := table.new_table()

	mut t := &Transpiler{tbl: table file: &file}

	assert map_ast['@type'].str() == 'Module'
	for node in map_ast['body'].arr() {
		file.stmts << t.visit_ast(node)
	}

	os.write_file(os.args[2], fmt.fmt(file, table, false)) 
}