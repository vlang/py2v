module main

import math

pub struct Version {
pub mut:
	major int
}

fn (mut self Version) init(major int) {
	self.major = major
}

fn (self Version) < (other Version) bool {
	return self.major < other.major
}

fn (self Version) == (other Version) bool {
	return self.major == other.major
}

fn (self Version) + (other Version) Version {
	return py2v_new_version(py2v_integer_generic_add1(self.major, other.major, 'operator_operand_types.py:18', |py2v_operand1, py2v_operand2| py2v_operand1 + py2v_operand2))
}

pub fn py2v_new_version(major int) Version {
	mut py2v_instance := Version{}
	py2v_instance.init(major)
	return py2v_instance
}

fn compare(a Version, b Version) bool {
	return a < b
}

fn add(a Version, b Version) Version {
	return a + b
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
