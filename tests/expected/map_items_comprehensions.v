module main

import pyrt

type Any = pyrt.Value

fn show(data map[string]Any, prefix string, skip string, enabled bool) {
	rendered := (fn [skip, prefix] (py2v_comp_map1 map[string]Any) map[string]Any {
		mut py2v_comp_result2 := map[string]Any{}
		for py2v_comp_key3, py2v_comp_value4 in py2v_comp_map1 {
			if !(py2v_comp_key3 != skip) { continue }
			py2v_comp_entry_key5 := prefix + py2v_comp_key3
			py2v_comp_entry_value6 := if (pyrt.type_name(py2v_comp_value4) in ['list', 'dict']) {
				py2v_comp_value4
			} else {
				pyrt.box(pyrt.str(py2v_comp_value4))
			}
			py2v_comp_result2[py2v_comp_entry_key5] = py2v_comp_entry_value6
		}
		return py2v_comp_result2
	})(data)
	println(pyrt.str(rendered['seen-b']))
	println(pyrt.length(rendered['seen-list']))
	records := if !enabled {
		[prefix]
	} else {
		(fn [skip, prefix] (py2v_comp_map7 map[string]Any) []string {
			mut py2v_comp_result8 := []string{}
			for py2v_comp_key9, py2v_comp_value10 in py2v_comp_map7 {
				if !(py2v_comp_key9 != skip) { continue }
				py2v_comp_result8 << prefix + pyrt.str(py2v_comp_value10)
			}
			return py2v_comp_result8
		})(data)
	}
	println(records.join(','))
	keys := py2v_distinct1((fn [skip, prefix] (py2v_comp_map11 map[string]Any) []string {
		mut py2v_comp_result12 := []string{}
		for py2v_comp_key13, py2v_comp_value14 in py2v_comp_map11 {
			if !(py2v_comp_key13 != skip) { continue }
			py2v_comp_result12 << prefix + py2v_comp_key13
		}
		return py2v_comp_result12
	})(data))
	println(if ('seen-a' in keys) { 'True' } else { 'False' })
	println(if ('seen-drop' in keys) { 'True' } else { 'False' })
}

fn py2v_distinct1[T](a []T) []T {
	mut b := []T{cap: a.len}
	for v in a {
		if v !in b {
			b << v
		}
	}
	return b
}

fn main() {
	show(map[string]Any{
		'a':    pyrt.box('hello')
		'b':    pyrt.box(7)
		'list': pyrt.box([pyrt.box(1), pyrt.box(2)])
		'drop': pyrt.box('ignored')
	}, 'seen-', 'drop', true)
}
