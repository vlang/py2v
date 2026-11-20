module main

import pyrt

type Any = pyrt.Value

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
