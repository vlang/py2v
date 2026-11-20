module main

import pyrt

type Any = pyrt.Value

fn label(nothing ?Any) string {
	return 'empty'
}

fn main() {
	println(label(none))
}
