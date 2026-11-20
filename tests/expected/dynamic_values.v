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

fn add(a Any, b Any) Any {
	return a + b
}

fn biggest(xs []int) int {
	mut best := xs[0]
	for x in xs {
		if x > best {
			best = x
		}
	}
	return best
}

fn first_or(xs Any, fallback Any) Any {
	if pyrt.truth(xs) {
		return pyrt.item_at(xs, pyrt.box(0))
	}
	return fallback
}

fn same(a Any, b Any) string {
	if pyrt.eq(a, b) {
		return 'same'
	}
	return 'different'
}

fn total(xs []int) int {
	mut t := xs[0]
	for x in xs[1..] {
		t = t + x
	}
	return t
}

fn main() {
	println(pyrt.str(add(1, 2)))
	println(pyrt.str(add('a', 'b')))
	println(pyrt.str(add(1.5, 2)))
	println(biggest([3, 9, 4]))
	println(pyrt.str(first_or(pyrt.box([pyrt.box(7)]), 0)))
	println(pyrt.str(first_or('', 'none')))
	println(same(1, 1.0))
	println(same('a', 1))
	println(total([1, 2, 3]))
}
