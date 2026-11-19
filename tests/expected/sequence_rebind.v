module main

import datatypes

fn replace(py2v_values_in1 []string, replace_now bool) int {
	mut values := py2v_values_in1.clone()
	if replace_now {
		values = ['replacement']
	}
	return values.len
}

fn forward(values []string, replace_now bool) int {
	return replace(values, replace_now)
}

fn main() {
	paths := ['first', 'second']
	println(forward(paths, false))
	println(forward(paths, true))
	println(paths.len)
}
