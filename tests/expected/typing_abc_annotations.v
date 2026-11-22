module main

import datatypes
import pyrt

type Any = pyrt.Value

fn bubble(mut collection []int) []int {
	n := collection.len
	py2v_range_stop1 := int(n)
	for i in int(0) .. py2v_range_stop1 {
		py2v_range_stop2 := int(n - 1 - i)
		for j in int(0) .. py2v_range_stop2 {
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

fn main() {
	println(bubble(mut [3, 1, 2]))
	println(first(['a', 'b']))
	println(describe('x', none))
	println(size([1, 2, 3].map(Any(it))))
}
