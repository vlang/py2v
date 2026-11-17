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

pub struct Score {
}

fn (self Score) < (other Score) bool {
	return false
}

fn (self Score) py_le(other Score) bool {
	return true
}

fn compare(a Score, b Score, c Score) bool {
	return py2v_unsupported_comparison_chain(['LtE', 'LtE'].map(Any(it)), a, b, c)
}
