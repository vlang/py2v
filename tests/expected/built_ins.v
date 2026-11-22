module main

import math
import arrays

fn default_builtins() {
	a := ''
	b := false
	c := 0
	d := 0.0
	assert a == ''
	assert b == false
	assert c == 0
	assert d == 0.0
}

fn main() {
	a := math.max(1, 2)
	println(a)
	b := math.min(1, 2)
	println(b)
	c := int(arrays.min([1.0, 2.0]) or { panic('!') })
	println(c)
}
