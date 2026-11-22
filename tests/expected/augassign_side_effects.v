module main

import pyrt
import math

pub struct Box {
pub mut:
	size int
}

fn (mut self Box) init(size int) {
	self.size = size
}

pub fn py2v_new_box(size int) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(size)
	return py2v_instance
}

pub struct Two {
}

fn (self Two) + (other Two) int {
	println('add')
	return 2
}

const py2v_idx17 = 17

pub struct Py2v {
}

fn index(i int) int {
	println('index ${i}')
	return i
}

fn key(k string) string {
	println('key ${k}')
	return k
}

fn grow_rows(mut rows [][]int) int {
	println('grow rows')
	rows << [5]
	return 0
}

fn grow_tail(py2v_rows_in1 &pyrt.ListRef[&pyrt.ListRef[int]]) int {
	mut rows := unsafe { py2v_rows_in1 }
	println('grow tail')
	rows.items << pyrt.list_ref[int]([7])
	return rows.items.len
}

fn main_func() {
	mut nums := [int(0), 8, 10]
	nums[0] = 3
	mut py2v_container2 := &nums
	py2v_index3 := index(0)
	py2v_old4 := (*py2v_container2)[if py2v_index3 < 0 {
		py2v_container2.len + py2v_index3
	} else {
		py2v_index3
	}]
	py2v_aug_result5 := py2v_integer_power1(py2v_old4, 2, 'augassign_side_effects.py:44')
	(*py2v_container2)[if py2v_index3 < 0 { py2v_container2.len + py2v_index3 } else { py2v_index3 }] = py2v_aug_result5
	mut py2v_container6 := &nums
	py2v_index7 := index(1)
	py2v_old8 := (*py2v_container6)[if py2v_index7 < 0 {
		py2v_container6.len + py2v_index7
	} else {
		py2v_index7
	}]
	py2v_aug_result9 := math.divide_floored[int](py2v_old8, 3).quot
	(*py2v_container6)[if py2v_index7 < 0 { py2v_container6.len + py2v_index7 } else { py2v_index7 }] = py2v_aug_result9
	nums[nums.len - 1] = py2v_integer_power1(nums[nums.len - 1], 2, 'augassign_side_effects.py:46')
	println(nums)
	mut grid := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([1, 2]),
		pyrt.list_ref[int]([3, 4])])
	grid.items[1] = pyrt.list_ref[int]([5, 6])
	mut py2v_list12 := unsafe { grid.items[index(1)] }
	mut py2v_container10 := &py2v_list12.items
	py2v_index11 := index(0)
	py2v_old13 := (*py2v_container10)[if py2v_index11 < 0 {
		py2v_container10.len + py2v_index11
	} else {
		py2v_index11
	}]
	py2v_aug_result14 := py2v_integer_power1(py2v_old13, 2, 'augassign_side_effects.py:52')
	(*py2v_container10)[if py2v_index11 < 0 {
		py2v_container10.len + py2v_index11
	} else {
		py2v_index11
	}] = py2v_aug_result14
	println(pyrt.str(pyrt.box(grid)))
	mut py2v_list17 := unsafe { pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](grid, index(0), index(2), true, true)).items[index(1)] }
	mut py2v_container15 := &py2v_list17.items
	py2v_index16 := 1
	py2v_old18 := (*py2v_container15)[if py2v_index16 < 0 {
		py2v_container15.len + py2v_index16
	} else {
		py2v_index16
	}]
	py2v_aug_result19 := math.divide_floored[int](py2v_old18, 2).quot
	(*py2v_container15)[if py2v_index16 < 0 {
		py2v_container15.len + py2v_index16
	} else {
		py2v_index16
	}] = py2v_aug_result19
	println(pyrt.str(pyrt.box(grid)))
	mut rows := [[2], [3]]
	rows[0] = [2]
	py2v_idx20 := rows.len - 1
	py2v_idx21 := grow_rows(mut rows)
	rows[py2v_idx20][py2v_idx21] = py2v_integer_power1(rows[py2v_idx20][py2v_idx21], 2, 'augassign_side_effects.py:62')
	println(rows)
	mut boxes := [py2v_new_box(1)]
	boxes[0] = py2v_new_box(3)
	py2v_idx22 := index(0)
	boxes[py2v_idx22].size = py2v_integer_power1(boxes[py2v_idx22].size, 2, 'augassign_side_effects.py:68')
	println(boxes[0].size)
	mut counts := map[string]int{
		'a': 9
	}
	counts['a'] = 10
	mut py2v_container23 := &counts
	py2v_index24 := key('a')
	py2v_old25 := (*py2v_container23)[py2v_index24]
	py2v_aug_result26 := math.divide_floored[int](py2v_old25, 3).quot
	(*py2v_container23)[py2v_index24] = py2v_aug_result26
	println(counts['a'])
	py2v_idx12 := 17
	mut tail := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([2]), pyrt.list_ref[int]([3])])
	tail.items[0] = pyrt.list_ref[int]([2])
	mut py2v_list29 := unsafe { pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](tail, -1, grow_tail(tail), true, true)).items[0] }
	mut py2v_container27 := &py2v_list29.items
	py2v_index28 := 0
	py2v_old30 := (*py2v_container27)[if py2v_index28 < 0 {
		py2v_container27.len + py2v_index28
	} else {
		py2v_index28
	}]
	py2v_aug_result31 := py2v_integer_power1(py2v_old30, 2, 'augassign_side_effects.py:83')
	(*py2v_container27)[if py2v_index28 < 0 {
		py2v_container27.len + py2v_index28
	} else {
		py2v_index28
	}] = py2v_aug_result31
	println(pyrt.str(pyrt.box(tail)))
	println(py2v_idx12)
	i := 0
	two := Two{}
	mut py2v_container32 := &nums
	py2v_index33 := i
	py2v_old34 := (*py2v_container32)[if py2v_index33 < 0 {
		py2v_container32.len + py2v_index33
	} else {
		py2v_index33
	}]
	(*py2v_container32)[if py2v_index33 < 0 {
		py2v_container32.len + py2v_index33
	} else {
		py2v_index33
	}] = py2v_integer_power1(py2v_old34, two + two, 'augassign_side_effects.py:91')
	nums[i] = py2v_integer_floor_div1(nums[i], int(i + 1), 'augassign_side_effects.py:92')
	println(nums)
	scale(5)
}

fn scale(py2v_idx16 int) {
	mut vals := [int(8), 9]
	vals[0] = 8
	mut py2v_container35 := &vals
	py2v_index36 := index(1)
	py2v_old37 := (*py2v_container35)[if py2v_index36 < 0 {
		py2v_container35.len + py2v_index36
	} else {
		py2v_index36
	}]
	py2v_aug_result38 := py2v_integer_floor_div1(py2v_old37, py2v_idx16, 'augassign_side_effects.py:102')
	(*py2v_container35)[if py2v_index36 < 0 {
		py2v_container35.len + py2v_index36
	} else {
		py2v_index36
	}] = py2v_aug_result38
	println(vals)
	println(py2v_idx16)
	println(py2v_idx17)
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_integer_power1(a int, b int, site string) int {
	if b < 0 { panic('py2v_unsupported_integer_power: a negative exponent needs a float result') }
	mut base, mut exponent := a, b
	mut result := 1
	for exponent != 0 {
		if exponent & 1 != 0 {
			result = py2v_integer_mul1(result, base, site, 'power')
		}
		exponent >>= 1
		if exponent != 0 {
			base = py2v_integer_mul1(base, base, site, 'power')
		}
	}
	return result
}

@[inline]
fn py2v_integer_floor_div1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

fn main() {
	main_func()
}
