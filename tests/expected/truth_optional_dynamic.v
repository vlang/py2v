module main

import pyrt

type Any = pyrt.Value

fn report(value ?Any) {
	if value != none && pyrt.truth(value) {
		println('yes')
	}
	println(if !(value != none && pyrt.truth(value)) { 'True' } else { 'False' })
}

fn main() {
	report(none)
	report(0)
	report('')
	report('x')
}
