module main

import os

pub struct Box {
pub mut:
	r int
}

fn (mut self Box) init(n int) {
	self.r = n
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
	println([1, 2].map(it + r_tail + tr))
	println([1].map('r'))
	println([1, 2].map('r=${it}'))
	println([Box{
		r: 3
	}].map(it.it))
	x := Box{
		r: 4
	}
	println([1, 2].map(x.it + it))
	println([Reader{}].map(it.it()))
	println([1, 2].filter(it >= 'r'.len).map(it))
	println([1, 2].map(it))
	println([1, 2].filter(it > 1).map(it))
	println([1, 2].map(it))
	println([[2, 5, 7]].map([it].map(1)))
	println([f].map(it(2, 10)))
	p := 'a/b.txt'
	paths := ['x/y.txt']
	println(os.file_name(p))
	println(paths.map(os.file_name(it)))
	println((fn () map[int]int {
		mut result := map[int]int{}
		for s in [2] {
			result[s] = [1, 2].filter(it >= 'r'.len).map(it).len
		}
		return result
	}()))
}

fn main() {
	main_func()
}
