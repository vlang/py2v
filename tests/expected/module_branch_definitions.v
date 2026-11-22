module main

import math

const py2v_branch_736372697074_1 = if option() { true } else { false }

const choose = if py2v_branch_736372697074_1 {
	py2v_branch_736372697074_2
} else {
	py2v_branch_736372697074_3
}

const offset = if py2v_branch_736372697074_1 {
	py2v_branch_736372697074_4
} else {
	py2v_branch_736372697074_5
}

fn option() bool {
	println('select')
	return false
}

fn py2v_branch_736372697074_2(value int) int {
	return py2v_integer_add1(value, 1, 'module_branch_definitions.py:8', 'addition')
}

fn py2v_branch_736372697074_3(value int) int {
	return py2v_integer_add1(value, 2, 'module_branch_definitions.py:14', 'addition')
}

fn py2v_branch_736372697074_4() int {
	return 10
}

fn py2v_branch_736372697074_5() int {
	return 20
}

fn use(value int) int {
	return py2v_integer_generic_add1(choose(value), offset(), 'module_branch_definitions.py:21', |py2v_operand1, py2v_operand2| py2v_operand1 + py2v_operand2)
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
	saved := choose
	println('${saved(5)} ${use(6)}')
}
