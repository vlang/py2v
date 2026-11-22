module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except (1 stmt)

fn with_finally(x int) int {
	mut result := 0
	defer {
		println('finally executed')
	}
	result = py2v_integer_mul1(x, 2, 'try_finally.py:4', 'multiplication')
	return result
}

fn main_func() {
	println(with_finally(5))
	println(with_finally(10))
	defer {
		println('cleanup')
	}
	x := 10
	println(x)
	// except handlers are not translated: see the TODO(py2v) note above
	//   except: 1 statement(s) need an `or { ... }` equivalent
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
	main_func()
}
