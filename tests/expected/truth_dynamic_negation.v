module main

import pyrt

type Any = pyrt.Value

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
