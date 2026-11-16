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

fn names(count int) []string {
	return []int{len: count, init: index}.map('n' + it.str())
}

fn lookup(key string) ?map[string]int {
	if key == '' {
		return none
	}
	return {
		key: key.len
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
	return [key, key.len]
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
