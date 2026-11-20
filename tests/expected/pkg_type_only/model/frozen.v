module py_pkg_type_only_model

import pyrt

type Any = pyrt.Value

pub fn frozen_count(values Any) int {
	return pyrt.length(values)
}
