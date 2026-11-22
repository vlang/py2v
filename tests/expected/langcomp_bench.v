module main

fn test_python(iterations int) {
	mut iteration := 0
	mut total := f64(0.0)
	array_length := 1000
	array := py2v_range_array1(0, py2v_range_bound1(array_length), 1).map(it)
	println('iterations ${iterations}')
	for iteration < iterations {
		mut innerloop := 0
		for innerloop < 100 {
			total += array[py2v_integer_mod1(int(iteration + innerloop), array_length, 'langcomp_bench.py:15')]
			innerloop = py2v_integer_add1(innerloop, 1, 'langcomp_bench.py:16', 'addition')
		}
		iteration = py2v_integer_add1(iteration, 1, 'langcomp_bench.py:17', 'addition')
	}
	if total == 15150 {
		println('OK')
	}
	// del array - V does not support deleting variables
}

@[inline]
fn py2v_range_bound1[T](value T) int {
	$if T is $int || T is bool {
		return int(value)
	} $else $if T is $sumtype {
		$for variant in T.variants {
			$if variant is $int || variant is bool {
				if value is variant {
					return int(value)
				}
			}
		}
		panic('TypeError: range needs integer bounds')
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
}

fn py2v_range_array1(start int, stop int, step int) []int {
	if step == 0 {
		panic('ValueError: range() arg 3 must not be zero')
	}
	mut values := []int{}
	for current := start; if step > 0 { current < stop } else { current > stop }; current += step {
		values << current
		if step > 0 {
			if u64(step) >= u64(stop) - u64(current) { break }
		} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
			break
		}
	}
	return values
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
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
	test_python(3)
}
