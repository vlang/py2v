module main

import pyrt

type Any = pyrt.Value

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
