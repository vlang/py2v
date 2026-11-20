module py_pkg_type_only_acyclic

import py_pkg_type_only_model
import pyrt

// TODO(py2v): module-level if statement has no place in a V module; move it into a function and call it explicitly.

type Any = pyrt.Value

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
