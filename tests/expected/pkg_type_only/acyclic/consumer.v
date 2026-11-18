module py_pkg_type_only_acyclic

import py_pkg_type_only_model
import pyrt

// TODO(py2v): module-level if statement has no place in a V module; move it into a function and call it explicitly.

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

pub struct Holder {
pub mut:
	item py_pkg_type_only_model.Item
}

pub fn take(value py_pkg_type_only_model.Item) int {
	return value.value
}

pub fn size(values []py_pkg_type_only_model.Item) int {
	return values.len
}

pub fn named(value py_pkg_type_only_model.Item) int {
	return value.value
}

pub fn opaque(value Any) int {
	return 5
}

pub fn nested(value Any) int {
	return 6
}
