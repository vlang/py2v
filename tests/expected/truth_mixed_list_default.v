module main

import pyrt

type Any = pyrt.Value

fn marker(value int) int {
	println('native ${value}')
	return value
}

fn report_py(flag bool, value Any) ! {
	selected := if flag { value } else { pyrt.empty_list() }
	result := if pyrt.truth(selected) { selected } else { pyrt.box([pyrt.box(marker(1))]) }
	pyrt.call_method(pyrt.box(result), 'append', [pyrt.box(2)])!
	println(pyrt.str(selected))
	println(pyrt.str(value))
	println(pyrt.str(result))
	println(pyrt.str(if pyrt.truth(selected) { selected } else { pyrt.empty_list() }))
}

fn py2v_entry1() ! {
	report_py(false, pyrt.box([pyrt.box(10)]))!
	report_py(true, pyrt.box([pyrt.box(10)]))!
	report_py(false, pyrt.empty_list())!
	report_py(true, pyrt.empty_list())!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
