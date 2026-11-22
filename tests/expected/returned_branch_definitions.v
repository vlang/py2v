module main

fn pick(mode int) fn (int) int {
	if mode == 1 {
		calculate := fn (value int) int {
			return value + 2
		}
		return calculate
	} else if mode == 2 {
		calculate := fn (value int) int {
			return py2v_integer_mul1(value, 2, 'returned_branch_definitions.py:10', 'multiplication')
		}
		return calculate
	} else {
		calculate := fn (value int) int {
			return value - 2
		}
		return calculate
	}
}

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

fn main() {
	first := pick(1)
	second := pick(2)
	third := pick(3)
	println('${first(5)} ${second(5)} ${third(5)}')
}
