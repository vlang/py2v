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
	return x + y
}

fn main_func() {
	r_tail := 10
	tr := 20
	println([' r '].map(it.trim_space()))
	println([1, 2].map(int(it + r_tail) + tr))
	println([1].map('r'))
	println([1, 2].map('r=${it}'))
	println([py2v_new_box(3)].map(it.it))
	x := py2v_new_box(4)
	println([1, 2].map(x.it + it))
	println([Reader{}].map(it.it()))
	println([1, 2].filter(it >= 'r'.len_utf8()))
	println([1, 2])
	println([1, 2].filter(it > 1))
	println([1, 2])
	println([[2, 5, 7]].map([it].map(1)))
	println([f].map(it(2, 10)))
	p := pathlib.new_path('a/b.txt')
	paths := [pathlib.new_path('x/y.txt')]
	println(p.name())
	println(paths.map(it.name()))
	println((fn () map[int]int {
		mut result := map[int]int{}
		for s in [2] {
			result[s] = [1, 2].count(it >= 'r'.len_utf8())
		}
		return result
	}()))
}

fn main() {
	main_func()
}
