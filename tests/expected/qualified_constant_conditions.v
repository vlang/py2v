module main

// TODO(py2v): no V equivalent for import token
// Provide one in python_to_v_import (types.v) or port the module.

fn advance(py2v_kind_in1 int, active bool) int {
	mut kind := py2v_kind_in1
	for (active && kind == token.STRING) {
		kind += 1
	}
	if (kind == token.NUMBER) {
		return kind + 1
	}
	return kind
}

fn follows() int {
	return 1
}
