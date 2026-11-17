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

fn append_bytes(items Any) {
	pyrt.invoke(items, 'append', pyrt.box([u8(0x41), 0x42]))
	println(pyrt.str(pyrt.item_at(items, pyrt.box(0))))
	println(pyrt.str(pyrt.invoke(pyrt.item_at(items, pyrt.box(0)), 'decode')))
}

fn main() {
	append_bytes(pyrt.empty_list())
}
