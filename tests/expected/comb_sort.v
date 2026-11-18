module main

import math
import pyrt
import arrays

fn comb_sort(py2v_seq_in1 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut seq := unsafe { py2v_seq_in1 }
	mut gap := seq.items.len
	mut swap := true
	for gap > 1 || swap {
		gap = arrays.max([1, int(math.floor(f64(gap) / 1.25))]) or { panic('!') }
		swap = false
		for i in []int{len: seq.items.len - gap, init: index} {
			if seq.items[i] > seq.items[i + gap] {
				seq.items[i], seq.items[i + gap] = seq.items[i + gap], seq.items[i]
				swap = true
			}
		}
	}
	return seq
}

fn main() {
	mut unsorted := pyrt.list_ref[int]([14, 11, 19, 5, 16, 10, 19, 12, 5, 12])
	expected := [5, 5, 10, 11, 12, 12, 14, 16, 19, 19]
	assert pyrt.eq(pyrt.box(comb_sort(unsorted)), pyrt.box(expected))
	println('OK')
}
