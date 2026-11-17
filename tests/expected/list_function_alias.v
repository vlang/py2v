module main

import pyrt
import arrays
import math

fn append_via_alias(py2v_values_in1 &pyrt.ListRef[int]) {
	mut values := unsafe { py2v_values_in1 }
	mut other := values
	other.items << 3
	values = pyrt.list_ref[int]([9])
	values.items << 10
	println(pyrt.str(pyrt.box(values)))
}

fn borrow_native(mut values []int) {
	values << 7
}

fn append_before_read(py2v_left_in2 &pyrt.ListRef[int], right &pyrt.ListRef[int]) {
	mut left := unsafe { py2v_left_in2 }
	left.items << 8
	println(pyrt.str(pyrt.box(right)))
}

fn split_sum(values []int) int {
	if values.len <= 1 {
		return arrays.sum(values) or { 0 }
	}
	mut left := []int{}
	mut right := []int{}
	for index, value in values {
		if index < math.divide_floored(values.len, 2).quot {
			left << value
		} else {
			right << value
		}
	}
	return split_sum(left) + split_sum(right)
}

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	append_via_alias(a)
	println(pyrt.str(pyrt.box(a)))
	mut unshared := [5, 6]
	borrow_native(mut unshared)
	println(unshared)
	read_only := [1, 2]
	read_alias := read_only
	println('${read_only} ${read_alias}')
	assert split_sum([1, 2, 3]) == 6
	mut same := pyrt.list_ref[int]([6])
	append_before_read(same, same)
	println(pyrt.str(pyrt.box(same)))
}

fn main() {
	main_func()
}
