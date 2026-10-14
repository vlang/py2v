module main

// TODO(py2v): no V equivalent for import adt
// Provide one in python_to_v_import (types.v) or port the module.

pub struct OpType {
pub mut:
	add &Callable
	mul &Callable
}
