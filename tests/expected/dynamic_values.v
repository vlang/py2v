module main

import math
import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn add(a Any, b Any) Any {
	return py2v_integer_generic_add1(a, b, 'dynamic_values.py:2', |py2v_operand1, py2v_operand2| py2v_operand1 + py2v_operand2)
}

fn biggest(xs []int) int {
	mut best := xs[0]
	for x in xs {
		if x > best {
			best = x
		}
	}
	return best
}

fn first_or(xs Any, fallback Any) Any {
	if pyrt.truth(xs) {
		return pyrt.item_at(xs, pyrt.box(0))
	}
	return fallback
}

fn same(a Any, b Any) string {
	if pyrt.eq(a, b) {
		return 'same'
	}
	return 'different'
}

fn total(xs []int) int {
	mut t := xs[0]
	for x in xs[1..] {
		t = py2v_integer_add1(t, x, 'dynamic_values.py:28', 'addition')
	}
	return t
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
	println(pyrt.str(add(1, 2)))
	println(pyrt.str(add('a', 'b')))
	println(pyrt.str(add(1.5, 2)))
	println(biggest([3, 9, 4]))
	println(pyrt.str(first_or(pyrt.box([pyrt.box(7)]), 0)))
	println(pyrt.str(first_or('', 'none')))
	println(same(1, 1.0))
	println(same('a', 1))
	println(total([1, 2, 3]))
}
