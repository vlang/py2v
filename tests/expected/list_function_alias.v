module main

import pyrt
import math

fn append_via_alias(py2v_values_in1 &pyrt.ListRef[int]) {
	mut values := unsafe { py2v_values_in1 }
	mut other := values
	other.items << 3
	values = pyrt.list_ref[int]([9])
	values.items << 10
	println(values.items.str())
}

fn borrow_native(mut values []int) {
	values << 7
}

fn append_before_read(py2v_left_in2 &pyrt.ListRef[int], right &pyrt.ListRef[int]) {
	mut left := unsafe { py2v_left_in2 }
	left.items << 8
	println(right.items.str())
}

fn split_sum(values []int) int {
	if values.len <= 1 {
		return py2v_integer_sum1(values, 0, 'list_function_alias.py:20')
	}
	mut left := []int{}
	mut right := []int{}
	for index, value in values {
		if index < math.divide_floored[int](values.len, 2).quot {
			left << value
		} else {
			right << value
		}
	}
	return py2v_integer_add1(split_sum(left), split_sum(right), 'list_function_alias.py:28', 'addition')
}

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	append_via_alias(a)
	println(a.items.str())
	mut unshared := [5, 6]
	borrow_native(mut unshared)
	println(unshared)
	read_only := [1, 2]
	read_alias := read_only
	println('${read_only} ${read_alias}')
	assert split_sum([1, 2, 3]) == 6
	mut same := pyrt.list_ref[int]([6])
	append_before_read(same, same)
	println(same.items.str())
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
