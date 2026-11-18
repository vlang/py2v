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
	py2v_idx2 := index(0)
	nums[py2v_idx2] = math.powi(nums[py2v_idx2], 2)
	py2v_idx3 := index(1)
	nums[py2v_idx3] = math.divide_floored(nums[py2v_idx3], 3).quot
	nums[nums.len - 1] = math.powi(nums[nums.len - 1], 2)
	println(nums)
	mut grid := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([1, 2]),
		pyrt.list_ref[int]([3, 4])])
	grid.items[1] = pyrt.list_ref[int]([5, 6])
	mut py2v_container4 := &(grid.items[index(1)].items)
	py2v_index5 := index(0)
	py2v_old6 := (*py2v_container4)[if py2v_index5 < 0 {
		py2v_container4.len + py2v_index5
	} else {
		py2v_index5
	}]
	(*py2v_container4)[if py2v_index5 < 0 { py2v_container4.len + py2v_index5 } else { py2v_index5 }] = math.powi(py2v_old6, 2)
	println(pyrt.str(pyrt.box(grid)))
	mut py2v_container7 := &(pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](grid, index(0), index(2), true, true)).items[index(1)].items)
	py2v_index8 := 1
	py2v_old9 := (*py2v_container7)[if py2v_index8 < 0 {
		py2v_container7.len + py2v_index8
	} else {
		py2v_index8
	}]
	(*py2v_container7)[if py2v_index8 < 0 { py2v_container7.len + py2v_index8 } else { py2v_index8 }] = math.divide_floored(py2v_old9, 2).quot
	println(pyrt.str(pyrt.box(grid)))
	mut rows := [[2], [3]]
	rows[0] = [2]
	py2v_idx10 := rows.len - 1
	py2v_idx11 := grow_rows(mut rows)
	rows[py2v_idx10][py2v_idx11] = math.powi(rows[py2v_idx10][py2v_idx11], 2)
	println(rows)
	mut boxes := [py2v_new_box(1)]
	boxes[0] = py2v_new_box(3)
	py2v_idx13 := index(0)
	boxes[py2v_idx13].size = math.powi(boxes[py2v_idx13].size, 2)
	println(boxes[0].size)
	mut counts := map[string]int{
		'a': 9
	}
	counts['a'] = 10
	py2v_idx14 := key('a')
	counts[py2v_idx14] = math.divide_floored(counts[py2v_idx14], 3).quot
	println(counts['a'])
	py2v_idx12 := 17
	mut tail := pyrt.list_ref[&pyrt.ListRef[int]]([pyrt.list_ref[int]([2]), pyrt.list_ref[int]([3])])
	tail.items[0] = pyrt.list_ref[int]([2])
	mut py2v_container15 := &(pyrt.list_ref[&pyrt.ListRef[int]](pyrt.list_ref_slice[&pyrt.ListRef[int]](tail, -1, grow_tail(tail), true, true)).items[0].items)
	py2v_index16 := 0
	py2v_old17 := (*py2v_container15)[if py2v_index16 < 0 {
		py2v_container15.len + py2v_index16
	} else {
		py2v_index16
	}]
	(*py2v_container15)[if py2v_index16 < 0 {
		py2v_container15.len + py2v_index16
	} else {
		py2v_index16
	}] = math.powi(py2v_old17, 2)
	println(pyrt.str(pyrt.box(tail)))
	println(py2v_idx12)
	i := 0
	two := Two{}
	py2v_idx18 := i
	nums[py2v_idx18] = math.powi(nums[py2v_idx18], two + two)
	nums[i] = math.divide_floored(nums[i], i + 1).quot
	println(nums)
	scale(5)
}

fn scale(py2v_idx16 int) {
	mut vals := [int(8), 9]
	vals[0] = 8
	py2v_idx19 := index(1)
	vals[py2v_idx19] = math.divide_floored(vals[py2v_idx19], py2v_idx16).quot
	println(vals)
	println(py2v_idx16)
	println(py2v_idx17)
}

fn main() {
	main_func()
}
