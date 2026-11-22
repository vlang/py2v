module main

import arrays

fn main_func() {
	nums := [3, 1, 4, 1, 5, 9, 2, 6]
	println(arrays.min(nums) or { panic('!') })
	println(arrays.max(nums) or { panic('!') })
	println(py2v_integer_sum1(nums, 0, 'min_max_sum.py:9'))
	println(arrays.min([10, 20]) or { panic('!') })
	println(arrays.max([10, 20]) or { panic('!') })
	println(arrays.min([5, 3]) or { panic('!') })
	println(arrays.max([5, 3]) or { panic('!') })
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

fn py2v_integer_sum1[T](items []T, start int, site string) int {
	$if (T is $int && T !is u64) || T is bool {
		mut total := start
		for item in items { total = py2v_integer_add1(total, int(item), site, 'sum') }
		return total
	} $else {
		$compile_error('py2v_unsupported_integer_sum: expected native integer elements')
	}
}

fn main() {
	main_func()
}
