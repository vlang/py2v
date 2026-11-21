module py_pkg_annotated_constants

pub type Index = int

pub const base = 3

pub const flags = [1 << base]

pub fn total() int {
	return flags[0]
}
