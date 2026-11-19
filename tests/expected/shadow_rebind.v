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

fn collect(path Any) Any {
	return path
}

fn first_existing(py2v_path_in1 Any) Any {
	mut path := py2v_path_in1
	for path_ in pyrt.elements(collect(path)) {
		path = path_
		println(pyrt.str(path_))
	}
	return path
}

fn rebind_local(items []int) int {
	mut total := 0
	for total_ in items {
		total = total_
		println(total_)
	}
	return total
}

fn destructure(py2v_path_in2 Any, rows Any) {
	mut path := py2v_path_in2
	py2v_seq3 := pyrt.elements(rows)
	for py2v_item4 in py2v_seq3 {
		name := py2v_item4[0]
		path_ := py2v_item4[1]
		value := py2v_item4[2]
		path = path_
		println('${name} ${pyrt.str(path_)} ${value}')
	}
}

fn main() {
	first_existing(1)
	rebind_local([1, 2])
	destructure('p', pyrt.box([pyrt.box([1, 2, 3])]))
}
