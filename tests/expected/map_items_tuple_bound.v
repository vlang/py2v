module main

import pyrt

fn main() {
	m := {
		'a': 2
		'b': 3
	}
	pairs := (fn (py2v_comp_map1 map[string]int) []pyrt.Value {
		mut py2v_comp_result2 := []pyrt.Value{}
		for py2v_comp_key3, py2v_comp_value4 in py2v_comp_map1 {
			py2v_comp_result2 << pyrt.Value(pyrt.new_tuple([pyrt.box(py2v_comp_key3),
				pyrt.box(py2v_comp_value4)]))
		}
		return py2v_comp_result2
	})(m)
	println(pyrt.str(pyrt.box(pairs)))
	println(pairs.len)
}
