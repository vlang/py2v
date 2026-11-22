module main

import math

fn show() {
	f := fn (x int) int {
		return x + 1
	}
	println(f(5))
	nums := [1, 2, 3]
	result := nums.map(fn (x int) i64 {
		return py2v_integer_mul1(x, 2, 'lambda_walrus.py:11', 'multiplication')
	})
	println(result.len)
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

fn py2v_integer_generic_mul1[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {
	$if A is $int && B is $int && R is $int {
		$if A is u64 || B is u64 || R is u64 {
			$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')
		} $else {
			value := py2v_integer_mul1(int(a), int(b), site, 'multiplication')
			if value < int(math.minof[R]()) || value > int(math.maxof[R]()) {
				py2v_integer_overflow1(site, 'integer narrowing')
			}
			return R(value)
		}
	} $else {
		return fallback(a, b)
	}
}

fn main() {
	show()
}
