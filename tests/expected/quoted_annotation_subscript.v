module main

import pyrt

type Any = pyrt.Value

fn names(count int) []string {
	return py2v_range_array1(0, count, 1).map('n' + it.str())
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

fn py2v_range_array1[A, B, C](begin A, end B, stride C) []int {
	$if (A is $int || A is bool) && (B is $int || B is bool) && (C is $int || C is bool) {
		start := int(begin)
		stop := int(end)
		step := int(stride)
		if step == 0 {
			panic('ValueError: range() arg 3 must not be zero')
		}
		mut values := []int{}
		for current := start; if step > 0 { current < stop } else { current > stop }; current += step {
			values << current
			if step > 0 {
				if u64(step) >= u64(stop) - u64(current) { break }
			} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
				break
			}
		}
		return values
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
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
