module main

import datatypes
import pyrt

type Any = pyrt.Value

fn bubble(mut collection []int) []int {
	n := collection.len
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(n)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		py2v_range_start4 := int(0)
		py2v_range_stop5 := int(n - 1 - i)
		py2v_range_step6 := int(1)
		if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for j := py2v_range_start4; if py2v_range_step6 > 0 {
			j < py2v_range_stop5
		} else {
			j > py2v_range_stop5
		}; j = py2v_range_next1(j, py2v_range_stop5, py2v_range_step6) {
			if collection[j] > collection[j + 1] {
				collection[j], collection[j + 1] = collection[j + 1], collection[j]
			}
		}
	}
	return collection
}

fn first(items []string) string {
	return items[0]
}

fn describe(label string, hook ?Any) string {
	if hook == none {
		return label + ' plain'
	}
	return label + ' hooked'
}

fn size(items []Any) int {
	return items.len
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
	println(bubble(mut [3, 1, 2]))
	println(first(['a', 'b']))
	println(describe('x', none))
	println(size([1, 2, 3].map(Any(it))))
}
