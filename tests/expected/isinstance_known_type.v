module main

import math

fn trailing_zeros(a int) int {
	if !true {
		panic('TypeError: ' + 'Input value must be an integer')
	}
	mut count := 0
	mut rest := a
	for rest > 0 && rest % 2 == 0 {
		rest = math.divide_floored(rest, 2).quot
		count += 1
	}
	return count
}

fn describe(x f64, name string) string {
	if true && true {
		return name + ' is a number'
	}
	return name + ' is not a number'
}

fn is_text(n int) string {
	if false {
		return 'text'
	}
	return 'not text'
}

fn total(items []int) int {
	if !true {
		return -1
	}
	mut result := 0
	for item in items {
		result += item
	}
	return result
}

fn run() {
	values := [int(1), 2, 3]
	println(trailing_zeros(8))
	println(describe(2.5, 'x'))
	println(is_text(4))
	println(total(values))
}

fn main() {
	run()
}
