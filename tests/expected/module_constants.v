module main

const seconds_per_minute_ = 60

const max_size = 3

const lower_ = 2

const names = ['a', 'b', 'c']

const units = {
	'k': 1000
	'm': 1000000
}

const double = py2v_integer_mul1(max_size, 2, 'module_constants.py:6', 'multiplication')

fn total() int {
	return py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_mul1(seconds_per_minute_, max_size, 'module_constants.py:12', 'multiplication')), lower_, 'module_constants.py:12', 'addition')), double, 'module_constants.py:12', 'addition')
}

fn pick(i int) string {
	return names[i]
}

fn scale(unit string) int {
	return units[unit]
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

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	mut counter := 0
	counter = py2v_integer_add1(counter, 1, 'module_constants.py:8', 'addition')
	println(total())
	println(pick(1))
	println(scale('m'))
	println(counter)
}
