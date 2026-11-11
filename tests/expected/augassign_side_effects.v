module main

import math

pub struct Box {
pub mut:
	size int
}

fn (mut self Box) init(size int) {
	self.size = size
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

fn grow_tail(mut rows [][]int) int {
	println('grow tail')
	rows << [7]
	return rows.len
}

fn main_func() {
	mut nums := [int(0), 8, 10]
	nums[0] = 3
	py2v_idx1 := index(0)
	nums[py2v_idx1] = math.powi(nums[py2v_idx1], 2)
	py2v_idx2 := index(1)
	nums[py2v_idx2] = math.divide_floored(nums[py2v_idx2], 3).quot
	nums[nums.len - 1] = math.powi(nums[nums.len - 1], 2)
	println(nums)
	mut grid := [[1, 2], [3, 4]]
	grid[1] = [5, 6]
	py2v_idx3 := index(1)
	py2v_idx4 := index(0)
	grid[py2v_idx3][py2v_idx4] = math.powi(grid[py2v_idx3][py2v_idx4], 2)
	println(grid)
	py2v_idx5 := index(0)
	py2v_idx6 := index(2)
	py2v_idx7 := index(1)
	grid[py2v_idx5..py2v_idx6][py2v_idx7][1] = math.divide_floored(grid[py2v_idx5..py2v_idx6][py2v_idx7][1], 2).quot
	println(grid)
	mut rows := [[2], [3]]
	rows[0] = [2]
	py2v_idx8 := rows.len - 1
	py2v_idx9 := grow_rows(mut rows)
	rows[py2v_idx8][py2v_idx9] = math.powi(rows[py2v_idx8][py2v_idx9], 2)
	println(rows)
	mut boxes := [Box{
		size: 1
	}]
	boxes[0] = Box{
		size: 3
	}
	py2v_idx10 := index(0)
	boxes[py2v_idx10].size = math.powi(boxes[py2v_idx10].size, 2)
	println(boxes[0].size)
	mut counts := {
		'a': 9
	}
	counts['a'] = 10
	py2v_idx11 := key('a')
	counts[py2v_idx11] = math.divide_floored(counts[py2v_idx11], 3).quot
	println(counts['a'])
	py2v_idx12 := 17
	mut tail := [[2], [3]]
	tail[0] = [2]
	py2v_idx13 := grow_tail(mut tail)
	py2v_idx14 := tail.len - 1
	tail[py2v_idx14..py2v_idx13][0][0] = math.powi(tail[py2v_idx14..py2v_idx13][0][0], 2)
	println(tail)
	println(py2v_idx12)
	i := 0
	two := Two{}
	py2v_idx15 := i
	nums[py2v_idx15] = math.powi(nums[py2v_idx15], two + two)
	nums[i] = math.divide_floored(nums[i], i + 1).quot
	println(nums)
	scale(5)
}

fn scale(py2v_idx16 int) {
	mut vals := [int(8), 9]
	vals[0] = 8
	py2v_idx18 := index(1)
	vals[py2v_idx18] = math.divide_floored(vals[py2v_idx18], py2v_idx16).quot
	println(vals)
	println(py2v_idx16)
	println(py2v_idx17)
}

fn main() {
	main_func()
}
