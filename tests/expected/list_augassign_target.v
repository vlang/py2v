module main

import pyrt

fn replace(py2v_rows_in1 &pyrt.ListRef[&pyrt.ListRef[int]]) []int {
	mut rows := unsafe { py2v_rows_in1 }
	println('replace')
	rows.items[0] = pyrt.list_ref[int]([9])
	return [2]
}

fn index() int {
	println('index')
	return 0
}

fn main_func() {
	a := pyrt.list_ref[int]([1])
	mut rows := pyrt.list_ref[&pyrt.ListRef[int]]([a])
	mut py2v_container2 := &(rows.items)
	py2v_index3 := index()
	mut py2v_old4 := (*py2v_container2)[if py2v_index3 < 0 {
		py2v_container2.len + py2v_index3
	} else {
		py2v_index3
	}]
	py2v_old4.items << replace(rows)
	(*py2v_container2)[if py2v_index3 < 0 { py2v_container2.len + py2v_index3 } else { py2v_index3 }] = py2v_old4
	println('${a.items.str()} ${rows.items[0].items.str()}')
}

fn main() {
	main_func()
}
