module main

import arrays

type Any = bool | int | i64 | f64 | string | []u8

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

// @wraps: unsupported decorator — remove or implement manually
fn wrapper(args ...Any, kwargs map[string]Any // **kwargs) Any {
	return func(...args, kwargs)
}
fn my_decorator(func Any) fn () Any {
	return wrapper
}

fn main() {
	println(fib(10))
	println(factorial(5))
}
