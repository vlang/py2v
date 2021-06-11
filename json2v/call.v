module json2v

import regex
import v.ast
import x.json2

fn (mut t Transpiler) visit_call(node json2.Any) ast.Expr {
	map_node := node.as_map()
	func := map_node['func'].as_map()

	mut args := []ast.CallArg{}
	for arg in map_node['args'].arr() {
		args << ast.CallArg{expr: t.visit_expr(arg) typ: ast.void_type}
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
					return ast.SelectorExpr{expr: args[0].expr field_name: 'len' scope: t.scope typ: ast.void_type expr_type: ast.void_type name_type: ast.void_type}
				}
				'bytes', 'bytearray' {
					typ := t.get_type(args[0].expr)
					$if debug {
						println('$name cast: has type "${t.tbl.get_type_name(typ)}"')
					}
					match typ {
						ast.new_type(t.tbl.find_or_register_array(ast.byte_type)) {
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
				'format' {
					if mut left is ast.StringLiteral {  // TODO: respect formatting spec
						mut vals := []string{cap: left.val.count('{')}
						mut start_idx := 0
						mut re := regex.regex_opt('{*.}') or { panic(err) }
						indices := re.find_all(left.val)

						for i in 0..indices.len/2 {
							vals << left.val[start_idx..indices[2 * i]]
							start_idx = indices[2 * i + 1]
						}

						if start_idx < left.val.len {
							vals << left.val[start_idx..left.val.len]
						}

						return ast.StringInterLiteral{vals: vals exprs: args.map(it.expr) need_fmts: args.map(false) fwidths: args.map(int(0)) precisions: args.map(int(987698)) pluss: args.map(false) fills: args.map(false)}
					}
				}
				else {}
			}
		}
		else {
			eprintln('unhandled func type in visit_call')
		}
	}

	return ast.CallExpr{name: name mod: mod args: args scope: t.scope left: left is_method: is_method return_type: ast.void_type receiver_type: ast.void_type}
}