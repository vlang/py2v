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

fn native_text() {
	record := {
		'full':  'text'
		'empty': ''
	}
	if record['full'] != '' {
		println('native')
	}
	println(if !(record['empty'] != '') { 'True' } else { 'False' })
}

fn report(items []int, data map[string]int) {
	println((if items.len > 0 { items } else { []int{} }).len)
	println((if items.len > 0 { [8] } else { items }).len)
	println((if data.len > 0 { data } else { map[string]int{} }).len)
	println((if data.len > 0 {
		({
			'selected': 9
		})
	} else {
		data
	}).len)
	println((if data.len > 0 {
		data
	} else {
		({
			'default': 7
		})
	}).len)
}

fn main() {
	native_text()
	empty := map[string]int{}
	full := {
		'key':   1
		'other': 2
	}
	report([], empty)
	report([1, 2], full)
}
