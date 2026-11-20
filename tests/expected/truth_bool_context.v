module main

import pyrt

type Any = pyrt.Value

fn probe(label string) string {
	println(label)
	return label
}

fn optional_text(value bool) ?string {
	if value {
		return 'present'
	}
	return none
}

fn report(items []int, data map[string]int, count int, flag bool) {
	empty_items := []int{}
	println(if !!(items.len > 0) { 'True' } else { 'False' })
	println(if !!(data.len > 0) { 'True' } else { 'False' })
	println(if !!flag { 'True' } else { 'False' })
	println(if !!(items.len > 0 || false) { 'True' } else { 'False' })
	println(if !!(data.len > 0 && map[string]Any{
		'key': 1
	}.len > 0) {
		'True'
	} else {
		'False'
	})
	println(if !!(count != 0 || 2 != 0) { 'True' } else { 'False' })
	println(if !!((if count != 0 { items } else { empty_items }).len > 0) {
		'True'
	} else {
		'False'
	})
	println(if !!((if count != 0 { count } else { 2 }) != 0) { 'True' } else { 'False' })
	println(if !!(count != 0) { 'True' } else { 'False' })
	println(if !!(if count != 0 { true } else { false }) { 'True' } else { 'False' })
}

fn dynamic(value Any) {
	println(if !!(pyrt.truth(value) || probe('dynamic-or') != '') { 'True' } else { 'False' })
	println(if !!(pyrt.truth(value) && probe('dynamic-and') != '') { 'True' } else { 'False' })
}

fn main() {
	empty := map[string]int{}
	full := {
		'key': 1
	}
	report([], empty, 0, false)
	report([1], full, 2, true)
	dynamic(0)
	dynamic('left')
	println(if !!(probe('first') != '' || probe('unused-or') != '') { 'True' } else { 'False' })
	println(if !!(probe('') != '' && probe('unused-and') != '') { 'True' } else { 'False' })
	println(if !!pyrt.has_text(optional_text(false)) { 'True' } else { 'False' })
	println(if !!pyrt.has_text(optional_text(true)) { 'True' } else { 'False' })
	println(if !!('literal' != '') { 'True' } else { 'False' })
	println(if !!false { 'True' } else { 'False' })
	println(if !!(0 != 0) { 'True' } else { 'False' })
	println(if !!(-0.25 != 0) { 'True' } else { 'False' })
}
