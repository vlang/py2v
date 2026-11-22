module main

import math

fn main_func() {
	a := [1, 2, 3]
	b := [2, 3, 4]
	println(if (1 in a) { 'True' } else { 'False' })
	println(if (5 in a) { 'True' } else { 'False' })
	@union := a | b
	println(@union)
	intersection := a & b
	println(intersection)
	difference := py2v_integer_generic_sub1(a, b, 'set_ops.py:16', |py2v_operand1, py2v_operand2| py2v_operand1 - py2v_operand2)
	println(difference)
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

fn py2v_integer_generic_sub1[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {
	$if A is $int && B is $int && R is $int {
		$if A is u64 || B is u64 || R is u64 {
			$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')
		} $else {
			value := py2v_integer_sub1(int(a), int(b), site, 'subtraction')
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
	main_func()
}
