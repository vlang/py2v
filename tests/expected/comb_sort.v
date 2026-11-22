module main

import math
import arrays

fn comb_sort(mut seq []int) []int {
	mut gap := seq.len
	mut swap := true
	for gap > 1 || swap {
		gap = arrays.max([1, int(math.floor(f64(f64(gap) / 1.25)))]) or { panic('!') }
		swap = false
		py2v_range_start1 := int(0)
		py2v_range_stop2 := int(seq.len - gap)
		py2v_range_step3 := int(1)
		if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for i := py2v_range_start1; if py2v_range_step3 > 0 {
			i < py2v_range_stop2
		} else {
			i > py2v_range_stop2
		}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
			if seq[i] > seq[i + gap] {
				seq[i], seq[i + gap] = seq[i + gap], seq[i]
				swap = true
			}
		}
	}
	return seq
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
	mut unsorted := [14, 11, 19, 5, 16, 10, 19, 12, 5, 12]
	expected := [5, 5, 10, 11, 12, 12, 14, 16, 19, 19]
	assert comb_sort(mut unsorted) == expected
	println('OK')
}
