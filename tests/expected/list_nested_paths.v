module main

import pyrt

fn main_func() {
	a := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([1])])
	mut copied := pyrt.list_ref[&pyrt.ListRef[int]](a.items.clone())
	copied.items[0].items << 2
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(copied))}')
	mut sliced := pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](a, 0, 0, false, false))
	sliced.items[0].items << 3
	println(pyrt.str(pyrt.box(a)))
	mut listed := pyrt.list_ref[&pyrt.ListRef[int]](a.items.clone())
	listed.items[0].items << 4
	println(pyrt.str(pyrt.box(a)))
	for i, row in a.items {
		mut py2v_iter_value1 := unsafe { row }
		py2v_iter_value1.items << i + 5
	}
	println(pyrt.str(pyrt.box(a)))
	values := {
		'row': a.items[0]
	}
	for row in values.values() {
		mut py2v_iter_value2 := unsafe { row }
		py2v_iter_value2.items << 6
	}
	for name, row in values {
		mut py2v_iter_value3 := unsafe { row }
		py2v_iter_value3.items << 7
	}
	println(pyrt.str(pyrt.box(a)))
}

fn main() {
	main_func()
}
