module main

import pyrt

type Any = pyrt.Value

pub struct Grid {
}

// NOTE: Tuple[slice, int] — define a struct with named fields
fn (self Grid) py2v_dunder_getitem(key []Any) string {
	return '${key[0].start}:${key[1]}'
}

fn main() {
	g := Grid{}
	println(py2v_unsupported_index_with_slice_axis(g, py2v_unsupported_slice(none, none, none), 1))
}
