module main

import arrays

fn main_func() {
	xs := [1, 2, 3]
	fs := [1.5, 2.5]
	base := 10
	step := 2
	println((arrays.sum(xs) or { 0 }) + 10)
	println((arrays.sum(xs) or { 0 }) + base)
	println(arrays.fold(fs, f64(0.5), |acc, x| acc + x))
	println(arrays.fold(fs, f64(10), |acc, x| acc + x))
	println(arrays.fold(fs, f64(base), |acc, x| acc + x))
	println(arrays.fold(xs, f64(0.5), |acc, x| acc + x))
	println((arrays.sum([]int{len: 4, init: index}) or { 0 }) + 3)
	println(((arrays.sum(xs) or { 0 }) + 10) * 2)
	println((arrays.sum(xs) or { 0 }) + 10)
	println((arrays.sum(xs) or { 0 }) + -1)
	println((arrays.sum(xs) or { 0 }) + (base - step))
}

fn main() {
	main_func()
}
