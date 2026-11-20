module main

import pyrt

type Any = pyrt.Value

fn local_text() {
	records := map[string]string{
		'title': 'ada'
	}
	println((records['title'] or { '' }).to_upper())
}

fn nested_int() {
	records := map[int]map[string]string{
		1: {
			'title': 'bea'
		}
	}
	println(records[1]['title'].to_upper())
}

fn nested_lookup() {
	records := map[string]map[string]string{
		'entry': {
			'title': 'gia'
		}
	}
	row := records['entry']
	println((row['title'] or { '' }).to_upper())
}

fn shared_value() {
	original := {
		'count': 1
	}
	mut records := map[string]map[string]int{
		'row': original
	}
	records['row']['count'] = 2
	println(original['count'])
}

fn bare_parameter_py(records map[string]string) ! {
	println(pyrt.str(pyrt.call_method(pyrt.box(records['title']), 'upper', [])!))
}

fn bare_parameter(records map[string]string) {
	bare_parameter_py(records) or { pyrt.fail(err) }
}

fn explicit_runtime_py(records map[string]Any) ! {
	println(pyrt.str(pyrt.call_method(pyrt.box(Any(pyrt.map_get(records, 'title', pyrt.box('')))), 'upper', [])!))
}

fn explicit_runtime(records map[string]Any) {
	explicit_runtime_py(records) or { pyrt.fail(err) }
}

fn runtime_local(value Any) Any {
	records := map[string]Any{
		'entry': pyrt.box(value)
	}
	return Any(pyrt.map_get(records, 'entry', pyrt.box('')))
}

fn empty_runtime() map[string]Any {
	mut records := map[string]Any{}
	records['title'] = 'ivy'
	return records
}

fn declared_float() {
	records := map[string]f64{
		'value': 1.5
	}
	println(records['value'])
}

fn rebound() {
	mut records := map[string]Any{
		'title': pyrt.box('jay')
	}
	records = {
		'title': 'kay'
	}
	println(pyrt.str(records['title']))
}

fn bare_return() map[string]string {
	return {
		'title': 'eli'
	}
}

fn main() {
	local_text()
	nested_int()
	nested_lookup()
	shared_value()
	bare_parameter(map[string]string{
		'title': 'cat'
	})
	explicit_runtime(map[string]Any{
		'title': 'dot'
	})
	println(pyrt.str(runtime_local('hop')))
	println(pyrt.str((pyrt.call_method(pyrt.box(Any(pyrt.map_get(empty_runtime(), 'title', pyrt.box('')))), 'upper', []) or { pyrt.fail(err) })))
	declared_float()
	rebound()
	println(pyrt.str((pyrt.call_method(pyrt.box(bare_return()['title']), 'upper', []) or { pyrt.fail(err) })))
}
