module main

import datatypes
import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn bubble(mut collection []int) []int {
	n := collection.len
	for i in []int{len: n, init: index} {
		for j in []int{len: n - 1 - i, init: index} {
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
