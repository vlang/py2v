module main

import arrays
import pyrt

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

// py2v: module-level list refusal: <module@6>: 10: shared list passed to an unresolved call; cannot preserve native list identity at this boundary

// py2v: module-level list refusal: <module@7>: 10: shared list passed to an unresolved call; cannot preserve native list identity at this boundary

// py2v: module-level list refusal: <module@10>: 10: shared list passed to an unresolved call; cannot preserve native list identity at this boundary

// py2v: module-level list refusal: <module@13>: 10: shared list passed to an unresolved call; cannot preserve native list identity at this boundary

// py2v: module-level list refusal: <module@19>: 10: shared list passed to an unresolved call; cannot preserve native list identity at this boundary

const py2v_list_identity_module_guard1 = py2v_unsupported_list_identity_module1()

fn main() {
	nums := [1, 2, 3]
	letters := ['a', 'b']
	chained := arrays.flatten([nums, letters])
	sliced := nums[..2]
	repeated := []Any{len: 3, init: 7} /* itertools.repeat */
	.clone()
	pairs := [][]Any{} /* itertools.product(nums, letters): use nested for loops */
	println(chained)
	println(sliced)
	println(repeated)
}
