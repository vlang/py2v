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
		else {
			eprintln('unhandled type ${map_node["@type"]}')
			ast.Expr(ast.None{})
		}
	}
}

fn visit_ast(node json2.Any) []ast.Stmt {
	map_node := node.as_map()
	mut stmts := []ast.Stmt{}
	match map_node['@type'].str() {
		'FunctionDef' {
			mut body_stmts := []ast.Stmt{}

			for node2 in map_node['body'].arr() {
				body_stmts << visit_ast(node2)
			}

			stmts << ast.FnDecl{return_type: table.void_type
								stmts: body_stmts
								name: map_node['name'].str()
								scope: voidptr(0)}
		}
		'Expr' {
			stmts << ast.ExprStmt{expr: visit_expr(map_node['value'])}
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
		file.stmts << visit_ast(node)
	}

	os.write_file(os.args[2], fmt.fmt(file, table, false)) 
}