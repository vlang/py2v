module py_pkg_type_only_cycle_b

import pyrt

type Any = pyrt.Value

pub fn answer(value Any) int {
	return 9
}
