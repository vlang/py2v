module main

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}

fn main() {
	a := [1, 2]
	b := [3]
	c := [4, 5, 6]
	n := 7
	println('${a.len} ${b.len} ${n} ${c.len}')
	println((1).str() + ' ' + ('2.5').str() + ' ' + ('word').str() + ' ' + (if true {
		'True'
	} else {
		'False'
	}).str() + ' ' + ('[1, 2]').str())
	println((py2v_integer_mul1(int(2 + 3), 4, 'print_mixed_args.py:7', 'multiplication')).str() + ' ' + (py2v_integer_sub1(n, 1, 'print_mixed_args.py:7', 'subtraction')).str() + ' ' + ('n=${n}').str())
}
