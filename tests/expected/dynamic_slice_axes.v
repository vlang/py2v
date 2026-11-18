module main

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

fn column(matrix Any, index int) Any {
	return py2v_unsupported_index_with_slice_axis(matrix, py2v_unsupported_slice(none, none, none), index)
}

fn window(matrix Any, start int, stop int, step int) Any {
	return py2v_unsupported_index_with_slice_axis(matrix, py2v_unsupported_slice(start, stop, step), py2v_unsupported_slice(none, none, none), 3)
}

fn set_column(mut matrix Any, index int, value int) {
	py2v_unsupported_index_with_slice_axis(matrix, py2v_unsupported_slice(none, none, none), index) = value
}

fn set_window(mut matrix Any, start int, stop int, step int, value int) {
	py2v_unsupported_index_with_slice_axis(matrix, py2v_unsupported_slice(start, stop, step), py2v_unsupported_slice(none, none, none), 3) = value
}

fn update_column(mut matrix Any, index int, value int) {
	py2v_unsupported_index_with_slice_axis(matrix, py2v_unsupported_slice(none, none, none), index) += value
}

fn annotate_column(mut matrix Any, index int, value int) {
	py2v_unsupported_index_with_slice_axis(matrix, py2v_unsupported_slice(none, none, none), index) := value
}

fn set_both(mut first Any, mut second Any, index int, value int) {
	py2v_unsupported_index_with_slice_axis(first, py2v_unsupported_slice(none, none, none), index) = value
	py2v_unsupported_index_with_slice_axis(second, py2v_unsupported_slice(1, none, none), index) = value
}
