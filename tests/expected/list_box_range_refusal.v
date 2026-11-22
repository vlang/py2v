module main

import pyrt

type Any = pyrt.Value

fn append_number_py(values Any, number Any) ! {
	pyrt.call_method(pyrt.box(values), 'append', [number])!
}

fn main_func_py() ! {
	source := pyrt.list_ref[int]([1])
	append_number_py(pyrt.box(source), py2v_integer_power1(2, 40, 'list_box_range_refusal.py:10'))!
	println(source.items.str())
}

fn py2v_entry1() ! {
	main_func_py()!
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

fn py2v_integer_power1(a int, b int, site string) int {
	if b < 0 { panic('py2v_unsupported_integer_power: a negative exponent needs a float result') }
	mut base, mut exponent := a, b
	mut result := 1
	for exponent != 0 {
		if exponent & 1 != 0 {
			result = py2v_integer_mul1(result, base, site, 'power')
		}
		exponent >>= 1
		if exponent != 0 {
			base = py2v_integer_mul1(base, base, site, 'power')
		}
	}
	return result
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
