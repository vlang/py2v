module main

import math

fn check_polygon(nums []int) bool {
	sorted_nums := nums.sorted()
	return sorted_nums[sorted_nums.len - 1] < py2v_integer_inferred_sum1(sorted_nums[..sorted_nums.len - 1], 0, 'sorted_typed_list.py:3')
}

fn smallest(items []int) int {
	ordered := items.sorted()
	return ordered[0]
}

fn same_digits(a int, b int) bool {
	return a.str().split('').sorted() == b.str().split('').sorted()
}

fn main_func() {
	println(if check_polygon([6, 10, 5]) { 'True' } else { 'False' })
	println(if check_polygon([3, 7, 13, 2]) { 'True' } else { 'False' })
	values := [5, 3, 9, 1]
	println(values.sorted())
	println(values)
	println(smallest(values))
	words := ['pear', 'apple', 'fig']
	println(words.sorted())
	println(if same_digits(125874, 251748) { 'True' } else { 'False' })
	println(if same_digits(12, 13) { 'True' } else { 'False' })
	println('hello'.split('').sorted())
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

fn py2v_integer_inferred_sum1[T](items []T, start int, site string) T {
	$if T is u64 {
		$compile_error('py2v_unsupported_wide_integer: sum may exceed u64')
	} $else $if T is $int {
		value := py2v_integer_sum1(items, start, site)
		if value < int(math.minof[T]()) || value > int(math.maxof[T]()) {
			py2v_integer_overflow1(site, 'integer narrowing')
		}
		return T(value)
	} $else $if T is $float {
		$compile_error('py2v_unsupported_unproven_float_sum: Python element types are not proven')
	} $else {
		$compile_error('py2v_unsupported_integer_sum: expected native integer elements')
	}
}

fn main() {
	main_func()
}
