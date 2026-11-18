module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

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

fn report(flag bool, value Any) {
	report_py(flag, value) or { pyrt.fail(err) }
}

fn main() {
	report(false, pyrt.box([pyrt.box(10)]))
	report(true, pyrt.box([pyrt.box(10)]))
	report(false, pyrt.empty_list())
	report(true, pyrt.empty_list())
}
