module main

import math

fn complex_test() {
	c1 := 2 + math.complex(0.0, 3.0)
	c2 := 4 + math.complex(0.0, 5.0)
	c3 := py2v_integer_generic_add1(c1, c2, 'complex.py:7', |py2v_operand1, py2v_operand2| py2v_operand1 + py2v_operand2)
	assert c3 == 6 + math.complex(0.0, 8.0)
	c4 := py2v_integer_generic_add1(c1, 3, 'complex.py:9', |py2v_operand3, py2v_operand4| py2v_operand3 + py2v_operand4)
	assert c4 == 5 + math.complex(0.0, 3.0)
	c5 := c1 + math.complex(0.0, 4.0)
	assert c5 == 2 + math.complex(0.0, 7.0)
	c6 := c3 - 2.3
	assert c6 == 3.7 + math.complex(0.0, 8.0)
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

fn py2v_integer_generic_add1[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {
	$if A is $int && B is $int && R is $int {
		$if A is u64 || B is u64 || R is u64 {
			$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')
		} $else {
			value := py2v_integer_add1(int(a), int(b), site, 'addition')
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
	complex_test()
	println('OK')
}
