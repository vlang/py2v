module main

import pyrt
import strconv

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
	println(py2v_float_text1(records['value']))
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

fn py2v_float_text1[T](value T) string {
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
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
