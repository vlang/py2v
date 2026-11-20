module main

import arrays
import pyrt

type Any = pyrt.Value

// @lru_cache: unsupported decorator — remove or implement manually
fn fib(n int) int {
	if n <= 1 {
		return n
	}
	return fib(n - 1) + fib(n - 2)
}

// @cache: unsupported decorator — remove or implement manually
fn factorial(n int) int {
	if n == 0 {
		return 1
	}
	return n * factorial(n - 1)
}

fn my_decorator(func Any) fn () Any {
	wrapper := py2v_unsupported_closure_decorator(fn (func Any, kwargs map[string]Any, args ...Any) Any {
		return func(...args, kwargs)
	}, wraps(func))
	return wrapper
}

fn main() {
	println(fib(10))
	println(factorial(5))
}
