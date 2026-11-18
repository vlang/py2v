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

fn report(flag bool, value Any) {
	selected := if flag { value } else { pyrt.empty_list() }
	result := if pyrt.truth(selected) { selected } else { pyrt.box([pyrt.box(marker(1))]) }
	pyrt.invoke(result, 'append', pyrt.box(2))
	println(pyrt.str(selected))
	println(pyrt.str(value))
	println(pyrt.str(result))
	println(pyrt.str(if pyrt.truth(selected) { selected } else { pyrt.empty_list() }))
}

fn main() {
	report(false, pyrt.box([pyrt.box(10)]))
	report(true, pyrt.box([pyrt.box(10)]))
	report(false, pyrt.empty_list())
	report(true, pyrt.empty_list())
}
