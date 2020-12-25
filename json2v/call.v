module main

import v.ast
import x.json2

fn visit_call(node json2.Any) ast.CallExpr {
	map_node := node.as_map()
	func := map_node['func'].as_map()

	mut name := ''
	mut left := ast.Expr(ast.None{})
	mut is_method := false
	match func['@type'].str() {
		'Name' {
			name = match func['id'].str() {
				'print' {
					'println'
				}
				else {
					func['id'].str()
				}
			}
		}
		'Attribute' {
			name = func['attr'].str()
			left = visit_expr(func['value'])
			is_method = true
		}
		else {
			eprintln('unhandled func type in visit_call')
		}
	}

	mut args := []ast.CallArg{}
	for arg in map_node['args'].arr() {
		args << ast.CallArg{expr: visit_expr(arg)}
	}

	return ast.CallExpr{name: name args: args scope: voidptr(0) left: left is_method: is_method}
}