module main

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

fn local_text() {
	records := {
		'title': 'ada'
	}
	println((records['title'] or { '' }).to_upper())
}

fn nested_int() {
	records := {
		1: {
			'title': 'bea'
		}
	}
	println(records[1]['title'].to_upper())
}

fn nested_lookup() {
	records := {
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
	mut records := {
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
	records := {
		'entry': value
	}
	return records['entry'] or { '' }
}

fn empty_runtime() map[string]Any {
	mut records := map[string]Any{}
	records['title'] = 'ivy'
	return records
}

fn declared_float() {
	records := {
		'value': 1.5
	}
	println(records['value'])
}

fn rebound() {
	mut records := {
		'title': 'jay'
	}
	records = {
		'title': 'kay'
	}
	println(records['title'])
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
