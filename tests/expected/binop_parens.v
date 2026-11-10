module main

import math

fn main_func() {
	a := 7
	b := 3
	c := 2
	println((a + b) * c)
	println(a - (b - c))
	println(a - (b + c))
	println(a * (b % c))
	println((a + b) % (b + c + 1))
	println(-(a - b) * c)
	println(~(a + b))
	println(+(b - a) * c)
	println((a + b) << c)
	println(a << (b + c))
	println(b & (a + c))
	println(a | (b ^ c))
	println(a * b + c)
	println(a - b - c)
	println(a ^ b & c)
	x := 7.5
	y := 2.5
	z := 3
	println(math.floor((x + y) / z))
	s := 'ab'
	t := 'c'
	println((s + t).repeat(2))
	p := true
	q := false
	r := true
	if p && (q || r) {
		println('p and (q or r)')
	}
	if (p && q) || r {
		println('(p and q) or r')
	}
	if p != (a < b) {
		println('p xor (a < b)')
	}
	println((s + (t + s)).to_upper())
	if p != ((q && r) == q) {
		println('wrong')
	} else {
		println('p xor ((q and r) == q) is false')
	}
	if p && (q || r) {
		println('p and (q or r), again')
	}
	println(-(-a))
	mut total := 0
	for i in []int{len: a + 1 - (c - (b - a)), init: index + (c - (b - a))} {
		total += i
	}
	println(total)
	mut w := 7.5
	w = math.floor(w / (y - (z - y)))
	println(w)
	println((t + '')[0])
	pair := [1, 7]
	if pair.len == 2 && (pair[0] == 1 || pair[0] == 2) && pair[1] == 7 {
		println('pair matched')
	} else {
		println('pair missed')
	}
}

fn main() {
	main_func()
}
