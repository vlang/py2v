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

fn has_small_value(items []Any) bool {
	for i, value in items {
		if value < i {
			return true
		}
	}
	return false
}

// NOTE: int | f64 — define: type X = int | f64
// NOTE: int | f64 — define: type X = int | f64
fn minimum(items []Any, last int) Any {
	if last == 0 {
		return items[0]
	}
	previous := minimum(items, last - 1)
	current := items[last]
	return if previous <= current { previous } else { current }
}

fn main() {
	println((if has_small_value([3, 0.5].map(Any(it))) { 'True' } else { 'False' }).str() + ' ' + (if has_small_value([
		3,
		2.5,
	].map(Any(it))) {
		'True'
	} else {
		'False'
	}).str())
	println(if minimum([2, 1, 3].map(Any(it)), 2) == minimum([1].map(Any(it)), 0) {
		'True'
	} else {
		'False'
	})
}
