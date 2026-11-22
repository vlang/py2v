module main

fn total(items []int) int {
	mut count := 0
	for item in items {
		count = py2v_integer_add1(count, item, 'module_name_shadowed.py:7', 'addition')
	}
	return count
}

fn describe(count int) string {
	return 'n=' + count.str()
}

fn twice(n int) int {
	count := n
	return py2v_integer_mul1(count, 2, 'module_name_shadowed.py:17', 'multiplication')
}

fn outer() int {
	inner := fn (count int) int {
		return py2v_integer_add1(count, 1, 'module_name_shadowed.py:29', 'addition')
	}
	other := fn () int {
		count := 10
		return py2v_integer_mul1(count, 3, 'module_name_shadowed.py:33', 'multiplication')
	}
	return py2v_integer_add1(inner(1), other(), 'module_name_shadowed.py:35', 'addition')
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
	mut count := 'three'
	numbers := [int(1), 2]
	println(total(numbers))
	println(describe(4))
	println(twice(5))
	println(count)
	println(outer())
}
