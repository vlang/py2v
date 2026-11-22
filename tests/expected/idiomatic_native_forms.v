module main

import math
import arrays

fn begin() int {
	println('begin')
	return 1
}

fn end() int {
	println('end')
	return 3
}

fn exercise(text string, stride int) {
	py2v_range_start1 := int(begin())
	py2v_range_stop2 := int(end())
	for i in py2v_range_start1 .. py2v_range_stop2 {
		println(i)
	}
	mut stop := 3
	py2v_range_stop3 := int(stop)
	for j in int(0) .. py2v_range_stop3 {
		println(j)
		stop = 0
	}
	py2v_range_start4 := int(4)
	py2v_range_stop5 := int(-1)
	py2v_range_step6 := int(stride)
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for k := py2v_range_start4; if py2v_range_step6 > 0 {
		k < py2v_range_stop5
	} else {
		k > py2v_range_stop5
	}; k = py2v_range_next1(k, py2v_range_stop5, py2v_range_step6) {
		println(k)
	}
	py2v_range_stop7 := int(1)
	for unused in int(3) .. py2v_range_stop7 {
		println(unused)
	}
	println(text.len_utf8())
	println(math.divide_floored[int](text.len_utf8(), 2).quot)
	println(-3)
	println(math.min(stride, 0))
	println(arrays.max([1, 2, 3]) or { panic('!') })
	mut first := [1, 2]
	second := [3, 4]
	println(arrays.append(first, second))
	println(arrays.append(arrays.append(arrays.append([0], first), second), [5]))
	println('${first} ${second}')
	println((fn (a [][]int, b [][]int) [][]int {
		mut r := a.clone()
		r << b
		return r
	}([[1]], [[2]])))
	println([1, 2, 3, 4].count(it > 1 && it < 4))
	println(first.filter(it > 1))
	copied := first.map(it)
	first << 8
	println(copied)
	values := [3, 1, 2]
	println(if values.map((5 - it in values)).any(it) { 'True' } else { 'False' })
	println(if values.map((it in values)).all(it) { 'True' } else { 'False' })
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}

fn main() {
	exercise('é🙂\x00x', -2)
}
