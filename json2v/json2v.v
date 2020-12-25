module main

import os
import v.ast
import v.fmt
import v.table
import x.json2

fn visit_constant(value json2.Any) ast.Expr {
	expr := match value {
		string {
			ast.Expr(ast.StringLiteral{val: value})
		}
		else {
			eprintln('unhandled constant type')
			ast.Expr(ast.None{})
		}
	}
	return expr
}

fn visit_expr(node json2.Any) ast.Expr {
	map_node := node.as_map()
	return match map_node['@type'].str() {
		'Call' {
			ast.Expr(visit_call(node))
		}
		'Constant' {
			visit_constant(map_node['value'])
		}
		'Name' {
			ast.Expr(ast.Ident{name: map_node['id'].str() scope: voidptr(0)})
		}
		else {
			eprintln('unhandled type ${map_node["@type"]}')
			ast.Expr(ast.None{})
		}
	}
}

fn visit_ast(node json2.Any, mut file ast.File) []ast.Stmt {
	map_node := node.as_map()
	mut stmts := []ast.Stmt{}
	match map_node['@type'].str() {
		'FunctionDef' {
			mut body_stmts := []ast.Stmt{}

			for node2 in map_node['body'].arr() {
				body_stmts << visit_ast(node2, mut file)
			}

			mut comments := []ast.Comment{}
			if body_stmts.len > 0 {
				first := body_stmts[0]
				if first is ast.ExprStmt {
					first_expr := first.expr
					if first_expr is ast.StringLiteral {
						comments << ast.Comment{text: first_expr.val}
						body_stmts.pop(0)
					}
				}
			}

			stmts << ast.FnDecl{return_type: table.void_type
								stmts: body_stmts
								name: map_node['name'].str()
								scope: voidptr(0)
								comments: comments}
		}
		'Expr' {
			stmts << ast.ExprStmt{expr: visit_expr(map_node['value'])}
		}
		'Assert' {
			stmts << ast.AssertStmt{expr: visit_expr(map_node['test'])}
		}
		'Import' {
			for imp in map_node['names'].arr() {
				map_imp := imp.as_map()
				if map_imp['asname'] is json2.Null {
					file.imports << ast.Import{mod: map_imp['name'].str() alias: map_imp['name'].str()}
				}
				else {
					file.imports << ast.Import{mod: map_imp['name'].str() alias: map_imp['asname'].str()}
				}
			}
		}
		else {
			eprintln('unhandled type ${map_node["@type"]}')
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
	table := table.new_table()

	assert map_ast['@type'].str() == 'Module'
	for node in map_ast['body'].arr() {
		file.stmts << visit_ast(node, mut file)
	}

	os.write_file(os.args[2], fmt.fmt(file, table, false)) 
}