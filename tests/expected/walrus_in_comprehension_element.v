module main

import arrays
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

fn main() {
	names := ['a-1', 'b-x', 'c-22']
	println(arrays.sum((fn () []Any {
		mut result := []Any{}
		for n in names {
			last := n.split('-')[n.split('-').len - 1]
			result << if (last.len > 0 && last.bytes().all(fn (c u8) bool { return c.is_digit() })) {
				last.int()
			} else {
				0
			}
		}
		return result
	})()) or { 0 })
	println((fn () []Any {
		mut result := []Any{}
		for n in names {
			result << py2v_unsupported_walrus_in_comprehension_element()
		}
		return result
	})())
}
