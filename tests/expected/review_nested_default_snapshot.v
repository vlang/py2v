module main

fn run() int {
	mut x := 3
	py2v_default1 := x
	inner := fn (v_ int) int {
		return v_
	}
	x = 11
	return inner(py2v_default1)
}

fn main() {
	println(run())
}
