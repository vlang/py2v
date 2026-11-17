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

fn receive(ch chan Any) {
	defer { ch.close() }
	sent := py2v_unsupported_generator_send(1)
	ch <- sent
}

fn delegate(ch chan Any) {
	defer { ch.close() }
	result := py2v_unsupported_yield_from_result(receive())
	return result
}

fn expression(ch chan Any) {
	defer { ch.close() }
	return py2v_unsupported_generator_send(2) + 1
}
