module main

import pyrt
import math

fn sorted_copy(values &pyrt.ListRef[int]) []int {
	mut result := pyrt.list_ref_slice[int](values, 0, 0, false, false)
	result.sort(a < b)
	return result
}

fn sort_in_place(py2v_values_in1 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut values := unsafe { py2v_values_in1 }
	values.items.sort(a < b)
	return values
}

fn swap_ends(py2v_values_in2 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut values := unsafe { py2v_values_in2 }
	values.items[0], values.items[values.items.len - 1] = values.items[values.items.len - 1], values.items[0]
	return values
}

fn drain(mut stack []int) int {
	mut total := 0
	for stack.len > 0 {
		total += stack.pop()
	}
	return total
}

fn group(numbers []int) map[int][]int {
	mut groups := map[int][]int{}
	for number in numbers {
		key := math.modulo_floored(number, 3)
		if (key !in groups) {
			groups[key] = []
		}
		groups[key] << number
	}
	return groups
}

fn collect(prefix int, mut out []int) {
	out << prefix
	if prefix < 3 {
		collect(prefix + 1, mut out)
	}
}

fn gather() []int {
	mut found := []int{}
	collect(1, mut found)
	return found
}

fn main() {
	mut unsorted := pyrt.list_ref[int]([5, 3, 9, 1])
	println(sorted_copy(unsorted))
	println(pyrt.str(pyrt.box(sort_in_place(unsorted))))
	mut letters := pyrt.list_ref[int]([4, 5, 6])
	letters.items.reverse_in_place()
	println(pyrt.str(pyrt.box(letters)))
	println(pyrt.str(pyrt.box(swap_ends(letters))))
	mut pending := [1, 2, 3]
	println('${drain(mut pending)} ${pending.len}')
	println(group([1, 2, 3, 4, 5, 6, 7]))
	println(gather())
	mut scratch := [7, 8]
	scratch.clear()
	println(scratch.len)
}
