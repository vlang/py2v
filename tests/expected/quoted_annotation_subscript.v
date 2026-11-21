module main

import pyrt

type Any = pyrt.Value

fn names(count int) []string {
	return []int{len: count, init: index}.map('n' + it.str())
}

fn lookup(key string) ?map[string]int {
	if key == '' {
		return none
	}
	return {
		key: py2v_text_length1(key)
	}
}

fn first(items []string) ?string {
	if items.len == 0 {
		return none
	}
	return items[0]
}

// NOTE: Tuple[?string, int] — define a struct with named fields
fn pair(key string) []Any {
	return [key, py2v_text_length1(key)]
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	println(names(2))
	println((if lookup('abc') == none { 'True' } else { 'False' }).str() + ' ' + (if lookup('') == none {
		'True'
	} else {
		'False'
	}).str())
	println((if first(names(2)) == none { 'True' } else { 'False' }).str() + ' ' + (if first([]) == none {
		'True'
	} else {
		'False'
	}).str())
	println(pair('ab').len)
}
