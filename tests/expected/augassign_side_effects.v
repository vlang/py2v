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
	mut py2v_container10 := &nums
	py2v_index11 := -1
	py2v_old12 := (*py2v_container10)[if py2v_index11 < 0 {
		py2v_container10.len + py2v_index11
	} else {
		py2v_index11
	}]
	py2v_aug_result13 := py2v_integer_power1(py2v_old12, 2, 'augassign_side_effects.py:46')
	(*py2v_container10)[if py2v_index11 < 0 {
		py2v_container10.len + py2v_index11
	} else {
		py2v_index11
	}] = py2v_aug_result13
	println(nums)
	mut grid := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([1, 2]),
		pyrt.list_ref[int]([3, 4])])
	grid.items[1] = pyrt.list_ref[int]([5, 6])
	mut py2v_list16 := unsafe { grid.items[index(1)] }
	mut py2v_container14 := &py2v_list16.items
	py2v_index15 := index(0)
	py2v_old17 := (*py2v_container14)[if py2v_index15 < 0 {
		py2v_container14.len + py2v_index15
	} else {
		py2v_index15
	}]
	py2v_aug_result18 := py2v_integer_power1(py2v_old17, 2, 'augassign_side_effects.py:52')
	(*py2v_container14)[if py2v_index15 < 0 {
		py2v_container14.len + py2v_index15
	} else {
		py2v_index15
	}] = py2v_aug_result18
	println(pyrt.str(pyrt.box(grid)))
	mut py2v_list21 := unsafe { pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](grid, index(0), index(2), true, true)).items[index(1)] }
	mut py2v_container19 := &py2v_list21.items
	py2v_index20 := 1
	py2v_old22 := (*py2v_container19)[if py2v_index20 < 0 {
		py2v_container19.len + py2v_index20
	} else {
		py2v_index20
	}]
	py2v_aug_result23 := math.divide_floored[int](py2v_old22, 2).quot
	(*py2v_container19)[if py2v_index20 < 0 {
		py2v_container19.len + py2v_index20
	} else {
		py2v_index20
	}] = py2v_aug_result23
	println(pyrt.str(pyrt.box(grid)))
	mut rows := [[2], [3]]
	rows[0] = [2]
	py2v_idx24 := rows.len - 1
	py2v_idx25 := grow_rows(mut rows)
	rows[py2v_idx24][py2v_idx25] = py2v_integer_power1(rows[py2v_idx24][py2v_idx25], 2, 'augassign_side_effects.py:62')
	println(rows)
	mut boxes := [py2v_new_box(1)]
	boxes[0] = py2v_new_box(3)
	py2v_idx26 := index(0)
	boxes[py2v_idx26].size = py2v_integer_power1(boxes[py2v_idx26].size, 2, 'augassign_side_effects.py:68')
	println(boxes[0].size)
	mut counts := map[string]int{
		'a': 9
	}
	counts['a'] = 10
	mut py2v_container27 := &counts
	py2v_index28 := key('a')
	py2v_old29 := (*py2v_container27)[py2v_index28]
	py2v_aug_result30 := math.divide_floored[int](py2v_old29, 3).quot
	(*py2v_container27)[py2v_index28] = py2v_aug_result30
	println(counts['a'])
	py2v_idx12 := 17
	mut tail := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([2]), pyrt.list_ref[int]([3])])
	tail.items[0] = pyrt.list_ref[int]([2])
	mut py2v_list33 := unsafe { pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](tail, -1, grow_tail(tail), true, true)).items[0] }
	mut py2v_container31 := &py2v_list33.items
	py2v_index32 := 0
	py2v_old34 := (*py2v_container31)[if py2v_index32 < 0 {
		py2v_container31.len + py2v_index32
	} else {
		py2v_index32
	}]
	py2v_aug_result35 := py2v_integer_power1(py2v_old34, 2, 'augassign_side_effects.py:83')
	(*py2v_container31)[if py2v_index32 < 0 {
		py2v_container31.len + py2v_index32
	} else {
		py2v_index32
	}] = py2v_aug_result35
	println(pyrt.str(pyrt.box(tail)))
	println(py2v_idx12)
	i := 0
	two := Two{}
	mut py2v_container36 := &nums
	py2v_index37 := i
	py2v_old38 := (*py2v_container36)[if py2v_index37 < 0 {
		py2v_container36.len + py2v_index37
	} else {
		py2v_index37
	}]
	(*py2v_container36)[if py2v_index37 < 0 {
		py2v_container36.len + py2v_index37
	} else {
		py2v_index37
	}] = py2v_integer_power1(py2v_old38, two + two, 'augassign_side_effects.py:91')
	mut py2v_container39 := &nums
	py2v_index40 := i
	py2v_old41 := (*py2v_container39)[if py2v_index40 < 0 {
		py2v_container39.len + py2v_index40
	} else {
		py2v_index40
	}]
	py2v_aug_result42 := py2v_integer_floor_div1(py2v_old41, int(py2v_integer_add1(i, 1, 'augassign_side_effects.py:92', 'addition')), 'augassign_side_effects.py:92')
	(*py2v_container39)[if py2v_index40 < 0 {
		py2v_container39.len + py2v_index40
	} else {
		py2v_index40
	}] = py2v_aug_result42
	println(nums)
	scale(5)
}

fn scale(py2v_idx16 int) {
	mut vals := [int(8), 9]
	vals[0] = 8
	mut py2v_container43 := &vals
	py2v_index44 := index(1)
	py2v_old45 := (*py2v_container43)[if py2v_index44 < 0 {
		py2v_container43.len + py2v_index44
	} else {
		py2v_index44
	}]
	py2v_aug_result46 := py2v_integer_floor_div1(py2v_old45, py2v_idx16, 'augassign_side_effects.py:102')
	(*py2v_container43)[if py2v_index44 < 0 {
		py2v_container43.len + py2v_index44
	} else {
		py2v_index44
	}] = py2v_aug_result46
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
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

@[inline]
fn py2v_integer_floor_div1(a int, b int, site string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	if b == -1 && a == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'floor division') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

fn main() {
	main_func()
}
