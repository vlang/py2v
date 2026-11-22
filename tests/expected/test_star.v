module main

import arrays
import pyrt

type Any = pyrt.Value

fn sum_all(nums ...Any) int {
	mut total := 0
	for n in nums {
		total = py2v_integer_add1(total, n, 'test_star.py:4', 'addition')
	}
	return total
}

fn main_func() {
	println('a'.repeat(5))
	println([0].repeat(3))
	numbers := [1, 2, 3]
	println(sum_all(...numbers))
	others := [4, 5]
	all_nums := arrays.append(arrays.append(arrays.append([0], numbers), others), [6])
	println(all_nums)
	data := [10, 20, 30, 40, 50]
	py2v_unpack1 := data
	mut a := py2v_unpack1[0]
	mut rest := py2v_unpack1[1..py2v_unpack1.len - 1]
	mut e := py2v_unpack1.last()
	println(a)
	println(rest)
	println(e)
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

fn main() {
	main_func()
}
