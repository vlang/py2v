module py_pkg_annotated_constants

// TODO(py2v): module-level statement has no place in a V module; move it into a function and call it explicitly.

pub const base = 3

pub const flags = [1 << base]

pub fn total() int {
	return flags[0]
}
