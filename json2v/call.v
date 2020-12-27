module main

import v.ast
import x.json2

fn (mut t Transpiler) visit_call(node json2.Any) ast.Expr {
	map_node := node.as_map()
	func := map_node['func'].as_map()

	mut args := []ast.CallArg{}
	for arg in map_node['args'].arr() {
		args << ast.CallArg{expr: t.visit_expr(arg)}
	}

	mut name := ''
	mut left := ast.Expr(ast.None{})
	mut is_method := false
	match func['@type'].str() {
		'Name' {
			match func['id'].str() {
				'print' {
					name = 'println'
				}
				'len' {
					return ast.SelectorExpr{expr: args[0].expr field_name: 'len' scope: voidptr(0)}
				}
				else {
					name = func['id'].str()
				}
			}
		}
		'Attribute' {
			name = func['attr'].str()
			left = t.visit_expr(func['value'])
			is_method = true
			match name {
				'islower' {
					name = 'is_lower'
				}
				'isupper' {
					name = 'is_upper'
				}
				'upper' {
					name = 'to_upper'
				}
				'lower' {
					name = 'to_lower'
				}
				else {}
			}
		}
		else {
			eprintln('unhandled func type in visit_call')
		}
	}

	return ast.CallExpr{name: name args: args scope: voidptr(0) left: left is_method: is_method}
}