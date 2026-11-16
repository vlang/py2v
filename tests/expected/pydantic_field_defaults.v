module main

// TODO(py2v): no V equivalent for import pydantic
// Provide one in python_to_v_import (types.v) or port the module.

pub struct Mood {
pub mut:
	mood      string
	valence   f64
	dominance f64     = 0.5
	category  ?string = none
	tags      []string
	weight    f64 = 1.5
	required  int
}
