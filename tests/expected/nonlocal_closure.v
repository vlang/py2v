module main

fn make_counter() fn () int {
	mut count := 0
	py2v_capture1 := &count
	increment := fn [py2v_capture1] () int {
		unsafe {
			(*py2v_capture1) += 1
		}
		return *py2v_capture1
	}
	return increment
}

fn make_adder(n int) fn (int) int {
	mut total := 0
	py2v_capture2 := &n
	py2v_capture3 := &total
	add := fn [py2v_capture2, py2v_capture3] (x int) int {
		unsafe {
			(*py2v_capture3) += x + (*py2v_capture2)
		}
		return *py2v_capture3
	}
	return add
}

fn main() {
	c := make_counter()
	println(c())
	println(c())
	add5 := make_adder(5)
	println(add5(1))
	println(add5(2))
}
