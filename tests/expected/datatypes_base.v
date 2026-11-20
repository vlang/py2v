module main

import pyrt

// TODO(py2v): no V equivalent for import adt
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

pub struct OpType {
pub mut:
	add Any
	mul Any
}
