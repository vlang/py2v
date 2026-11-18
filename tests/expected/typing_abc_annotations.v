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

fn bubble(py2v_collection_in1 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut collection := unsafe { py2v_collection_in1 }
	n := collection.items.len
	for i in []int{len: n, init: index} {
		for j in []int{len: n - 1 - i, init: index} {
			if collection.items[j] > collection.items[j + 1] {
				collection.items[j], collection.items[j + 1] = collection.items[j + 1], collection.items[j]
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
	println(pyrt.str(pyrt.box(bubble(pyrt.list_ref[int]([3, 1, 2])))))
	println(first(['a', 'b']))
	println(describe('x', none))
	println(size([1, 2, 3].map(Any(it))))
}
