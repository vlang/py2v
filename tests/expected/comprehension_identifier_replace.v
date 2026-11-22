module main

import os
import pyrt.pathlib

pub struct Box {
pub mut:
	r int
}

fn (mut self Box) init(n int) {
	self.r = n
}

pub fn py2v_new_box(n int) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(n)
	return py2v_instance
}

pub struct Reader {
}

fn (self Reader) r() int {
	return 3
}

fn f(x int, y int) int {
	return py2v_integer_add1(x, y, 'comprehension_identifier_replace.py:13', 'addition')
}

fn main_func() {
	r_tail := 10
	tr := 20
	println([' r '].map(it.trim_space()))
	println([1, 2].map(py2v_integer_add1(int(py2v_integer_add1(it, r_tail, 'comprehension_identifier_replace.py:19', 'addition')), tr, 'comprehension_identifier_replace.py:19', 'addition')))
	println([1].map('r'))
	println([1, 2].map('r=${it}'))
	println([py2v_new_box(3)].map(it.it))
	x := py2v_new_box(4)
	println([1, 2].map(py2v_integer_add1(x.it, it, 'comprehension_identifier_replace.py:24', 'addition')))
	println([Reader{}].map(it.it()))
	println([1, 2].filter(it >= py2v_text_length1('r')).map(it))
	println([1, 2].map(it))
	println([1, 2].filter(it > 1).map(it))
	println([1, 2].map(it))
	println([[2, 5, 7]].map([it].map(1)))
	println([f].map(it(2, 10)))
	p := pathlib.new_path('a/b.txt')
	paths := [pathlib.new_path('x/y.txt')]
	println(p.name())
	println(paths.map(it.name()))
	println((fn () map[int]int {
		mut result := map[int]int{}
		for s in [2] {
			result[s] = [1, 2].filter(it >= py2v_text_length1('r')).map(it).len
		}
		return result
	}()))
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	main_func()
}
