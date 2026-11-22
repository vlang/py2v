module main

fn outer(type_ int, name int, annotation int) int {
	py2v_capture1 := &type_
	py2v_capture2 := &annotation
	py2v_capture3 := &name
	inner := fn [py2v_capture1, py2v_capture2, py2v_capture3] () int {
		return int((*py2v_capture1) + (*py2v_capture3)) + (*py2v_capture2)
	}
	return inner()
}

fn main() {
	println(outer(10, 20, 12))
}
