module main

import math
import arrays

fn comb_sort(mut seq []int) []int {
	mut gap := seq.len
	mut swap := true
	for gap > 1 || swap {
		gap = arrays.max([1,
			py2v_integer_from_float1(math.floor(f64(f64(gap) / 1.25)), 'comb_sort.py:11')]) or { panic('!') }
		swap = false
		py2v_range_start1 := int(0)
		py2v_range_stop2 := int(py2v_integer_sub1(seq.len, gap, 'comb_sort.py:13', 'subtraction'))
		py2v_range_step3 := int(1)
		if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for i := py2v_range_start1; if py2v_range_step3 > 0 {
			i < py2v_range_stop2
		} else {
			i > py2v_range_stop2
		}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
			if seq[i] > seq[py2v_integer_add1(i, gap, 'comb_sort.py:14', 'addition')] {
				seq[i], seq[py2v_integer_add1(i, gap, 'comb_sort.py:15', 'addition')] = seq[py2v_integer_add1(i, gap, 'comb_sort.py:15', 'addition')], seq[i]
				swap = true
			}
		}
	}
	return seq
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_from_float1(value f64, site string) int {
	if !(value >= -9223372036854775808.0 && value < 9223372036854775808.0) {
		py2v_integer_overflow1(site, 'float to integer conversion')
	}
	return int(value)
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
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

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	mut unsorted := [14, 11, 19, 5, 16, 10, 19, 12, 5, 12]
	expected := [5, 5, 10, 11, 12, 12, 14, 16, 19, 19]
	assert comb_sort(mut unsorted) == expected
	println('OK')
}
