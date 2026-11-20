module main

import datatypes
import pyrt

type Any = pyrt.Value

fn size(values map[string]Any) int {
	return values.len
}

fn main() {
	values := map[string]Any{}
	println(size(values))
}
