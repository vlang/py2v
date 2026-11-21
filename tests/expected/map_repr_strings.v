module main

import pyrt

fn describe(values []string) string {
	return values.map(pyrt.repr(pyrt.box(it))).join('|')
}

fn main() {
	println(describe(['plain', "it's", '\nß']))
}
