module main

import pyrt

type Any = pyrt.Value

fn vararg_rebind(values ...int) {
	mut py2v_param_rebind1 := Any(pyrt.new_tuple(values.map(pyrt.box(it))))
	for values_ in values {
		py2v_param_rebind1 = pyrt.box(values_)
		// pass
	}
	println(pyrt.str(py2v_param_rebind1))
}

fn vararg_branch_len(flag bool, values ...int) {
	mut py2v_param_rebind2 := Any(pyrt.new_tuple(values.map(pyrt.box(it))))
	if flag {
		n := values.len
		for values_ in values {
			py2v_param_rebind2 = pyrt.box(values_)
			// pass
		}
		println(n)
	}
	println(pyrt.str(py2v_param_rebind2))
}

fn vararg_iter_len(args ...int) {
	mut py2v_param_rebind3 := Any(pyrt.new_tuple(args.map(pyrt.box(it))))
	py2v_range_stop4 := int(args.len)
	for i in int(0) .. py2v_range_stop4 {
		for args_ in [1, 2] {
			py2v_param_rebind3 = pyrt.box(args_)
			// pass
		}
	}
	println(pyrt.str(py2v_param_rebind3))
}

fn main() {
	vararg_rebind(2, 3)
	vararg_branch_len(true, 2, 3)
	vararg_branch_len(false, 2, 3)
	vararg_iter_len(10, 20)
}
