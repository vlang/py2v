module main

fn get_number() int {
	println('DEFAULT_EVAL')
	return 8
}

fn run() int {
	py2v_default1 := get_number()
	inner := fn (v_ int) int {
		return v_
	}
	return inner(py2v_default1) + inner(py2v_default1)
}

fn main() {
	println(run())
}
