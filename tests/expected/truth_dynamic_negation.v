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

fn probe() Any {
	println('probe')
	return 'answer'
}

fn report(value Any) {
	println(if !(pyrt.truth(value) && pyrt.truth(probe())) { 'True' } else { 'False' })
	println(if !(pyrt.truth(value) || pyrt.truth(probe())) { 'True' } else { 'False' })
	println(if !(pyrt.truth(value) && (pyrt.truth(probe()) || pyrt.truth(value))) {
		'True'
	} else {
		'False'
	})
}

fn main() {
	report(0)
	report('left')
}
