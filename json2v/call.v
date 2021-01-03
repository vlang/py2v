module main

import v.ast
import v.table
import x.json2

fn (mut t Transpiler) visit_call(node json2.Any) ast.Expr {
	map_node := node.as_map()
	func := map_node['func'].as_map()

	mut args := []ast.CallArg{}
	for arg in map_node['args'].arr() {
		args << ast.CallArg{expr: t.visit_expr(arg) typ: table.void_type}
	}

	mut name := ''
	mut mod := ''
	mut left := ast.Expr(ast.None{})
	mut is_method := false
	match func['@type'].str() {
		'Name' {
			name = func['id'].str()
			match name {
				'print' {
					name = 'println'
					mod = 'main'
				}
				'len' {
					return ast.SelectorExpr{expr: args[0].expr field_name: 'len' scope: t.scope typ: table.void_type expr_type: table.void_type name_type: table.void_type}
				}
				'bytes', 'bytearray' {
					typ := t.get_type(args[0].expr)
					$if debug {
						println('$name cast: has type "${t.tbl.get_type_name(typ)}"')
					}
					match typ {
						table.new_type(t.tbl.find_or_register_array(table.byte_type, 1)) {
							return args[0].expr
						}
						else {
							name = '[]byte' // this will not work
						}
					}
				}
				else {}
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

	return ast.CallExpr{name: name mod: mod args: args scope: t.scope left: left is_method: is_method return_type: table.void_type receiver_type: table.void_type}
}