module main

import pyrt

fn bubble_sort(py2v_seq_in1 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut seq := unsafe { py2v_seq_in1 }
	L := seq.items.len
	for _ in []int{len: L, init: index} {
		for n in []int{len: L - 1, init: index + 1} {
			if seq.items[n] < seq.items[n - 1] {
				seq.items[n - 1], seq.items[n] = seq.items[n], seq.items[n - 1]
			}
		}
	}
	return seq
}

fn main() {
	mut unsorted := pyrt.list_ref[int]([14, 11, 19, 5, 16, 10, 19, 12, 5, 12])
	expected := [5, 5, 10, 11, 12, 12, 14, 16, 19, 19]
	assert pyrt.eq(pyrt.box(bubble_sort(unsorted)), pyrt.box(expected))
	println('OK')
}
