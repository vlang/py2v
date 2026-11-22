module main

fn total(start int) int {
	mut value := start
	py2v_capture1 := &value
	add := fn [py2v_capture1] (amount int) int {
		unsafe {
			(*py2v_capture1) = py2v_integer_add1((*py2v_capture1), amount, 'nested_closures.py:6', 'addition')
		}
		py2v_capture2 := &(*py2v_capture1)
		finish := fn [py2v_capture2] (extra int) int {
			return py2v_integer_add1((*py2v_capture2), extra, 'nested_closures.py:9', 'addition')
		}
		return finish(1)
	}
	first := add(2)
	second := add(3)
	return py2v_integer_add1(int(py2v_integer_add1(first, second, 'nested_closures.py:15', 'addition')), value, 'nested_closures.py:15', 'addition')
}

fn recursive(n int) int {
	mut count := 0
	mut factorial := fn (k int) int { panic('uninitialized recursive closure') }
	py2v_capture3 := &count
	factorial = fn [py2v_capture3, mut factorial] (k int) int {
		unsafe {
			(*py2v_capture3) = py2v_integer_add1((*py2v_capture3), 1, 'nested_closures.py:23', 'addition')
		}
		if k <= 1 {
			return 1
		}
		return py2v_integer_mul1(k, factorial(py2v_integer_sub1(k, 1, 'nested_closures.py:26', 'subtraction')), 'nested_closures.py:26', 'multiplication')
	}
	result := factorial(n)
	return py2v_integer_add1(int(py2v_integer_mul1(result, 10, 'nested_closures.py:29', 'multiplication')), count, 'nested_closures.py:29', 'addition')
}

fn choose(x int) int {
	return py2v_integer_add1(x, 3, 'nested_closures.py:35', 'addition')
}

fn conditional(flag bool) int {
	if flag {
		// pass
		return choose(5)
	}
	return 0
}

fn siblings(n int) int {
	mut state := n
	py2v_capture4 := &state
	write := fn [py2v_capture4] (x int) int {
		unsafe {
			(*py2v_capture4) = x
		}
		return *py2v_capture4
	}
	py2v_capture5 := &state
	read := fn [py2v_capture5] () int {
		return *py2v_capture5
	}
	write(9)
	return py2v_integer_add1(read(), state, 'nested_closures.py:52', 'addition')
}

fn late_read() int {
	mut value := 1
	py2v_capture6 := &value
	read := fn [py2v_capture6] () int {
		return *py2v_capture6
	}
	value = 6
	return read()
}

fn default_first() int {
	pick := fn (x int) int {
		return x
	}
	return pick(7)
}

fn default_second() int {
	pick := fn () int {
		return 9
	}
	return pick()
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
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
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
	println(total(10))
	println(recursive(4))
	println(conditional(true))
	println(siblings(3))
	println(late_read())
	println(default_first())
	println(default_second())
}
