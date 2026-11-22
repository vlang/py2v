module main

import pyrt

// TODO(py2v): no V equivalent for import unavailable
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

fn compute(value int) int {
	println(value)
	return value
}

fn construct_py() !Any {
	return pyrt.untranslated_import('unavailable.Widget')!
}

fn method_py(receiver Any) !Any {
	return pyrt.call(pyrt.getattr(pyrt.box(receiver), 'Upper')!, [
		pyrt.box(compute(4)),
		pyrt.box(compute(5)),
	])!
}
