module main

import arrays
import pyrt

type Any = pyrt.Value

// @lru_cache: unsupported decorator — remove or implement manually
fn fib(n int) int {
	if n <= 1 {
		return n
	}
	return py2v_integer_add1(fib(py2v_integer_sub1(n, 1, 'functools_decorators.py:8', 'subtraction')), fib(py2v_integer_sub1(n, 2, 'functools_decorators.py:8', 'subtraction')), 'functools_decorators.py:8', 'addition')
}

// @cache: unsupported decorator — remove or implement manually
fn factorial(n int) int {
	if n == 0 {
		return 1
	}
	return py2v_integer_mul1(n, factorial(py2v_integer_sub1(n, 1, 'functools_decorators.py:15', 'subtraction')), 'functools_decorators.py:15', 'multiplication')
}

fn my_decorator(func Any) fn () Any {
	wrapper := py2v_unsupported_closure_decorator(fn (func Any, kwargs map[string]Any, args ...Any) Any {
		return func(...args, kwargs)
	}, wraps(func))
	return wrapper
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
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
	println(fib(10))
	println(factorial(5))
}
