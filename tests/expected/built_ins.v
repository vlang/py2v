module main

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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_from_float1(value f64, site string) int {
	if !(value >= -9223372036854775808.0 && value < 9223372036854775808.0) {
		py2v_integer_overflow1(site, 'float to integer conversion')
	}
	return int(value)
}

fn main() {
	a := arrays.max([1, 2]) or { panic('!') }
	println(a)
	b := arrays.min([1, 2]) or { panic('!') }
	println(b)
	c := py2v_integer_from_float1(arrays.min([1.0, 2.0]) or { panic('!') }, 'built_ins.py:20')
	println(c)
}
