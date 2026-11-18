module main

fn run() int {
	x := 3
	py2v_default1 := x
	inner := fn (v_ int) int {
		return v_
	}
	return inner(py2v_default1)
}

fn main() {
	println(run())
}
