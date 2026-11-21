module main

import pyrt

type Any = pyrt.Value

fn marker(value int) int {
	println('native ${value}')
	return value
}

fn report_py(flag bool, value Any) ! {
	selected := if flag { value } else { pyrt.box([pyrt.box(marker(1))]) }
	pyrt.call_method(pyrt.box(selected), 'append', [pyrt.box(2)])!
	println(pyrt.str(selected))
	println(pyrt.str(value))
	println(pyrt.str(if flag { value } else { pyrt.box([pyrt.box([pyrt.box(marker(3))])]) }))
	println(pyrt.str(if flag {
		value
	} else {
		pyrt.box(map[string]Any{
			'key': pyrt.box([pyrt.box(marker(4))])
		})
	}))
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
