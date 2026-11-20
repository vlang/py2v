module main

import pyrt

// TODO(py2v): no V equivalent for import adt
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

pub struct IntListNonEmpty {
pub mut:
	first int
	rest  &IntList
}

pub struct IntList {
pub mut:
	NONE Any
	REST &IntListNonEmpty
}
