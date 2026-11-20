module main

import pyrt

type Any = pyrt.Value

fn report(items []Any) {
	println((if items.len > 0 { items } else { []Any{} }).len)
	if items.len > 0 {
		println('items')
	}
	println(if !(items.len > 0) { 'True' } else { 'False' })
}

fn main() {
	report([])
	report([1].map(Any(it)))
}
