module main

fn outer(type_ int, name int, annotation int) int {
	py2v_capture1 := &type_
	py2v_capture2 := &annotation
	py2v_capture3 := &name
	inner := fn [py2v_capture1, py2v_capture2, py2v_capture3] () int {
		return py2v_integer_add1(int(py2v_integer_add1((*py2v_capture1), (*py2v_capture3), 'closure_capture_discriminator.py:3', 'addition')), (*py2v_capture2), 'closure_capture_discriminator.py:3', 'addition')
	}
	return inner()
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	println(outer(10, 20, 12))
}
