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

pub struct Holder {
pub mut:
	kind Any
}

fn (mut self Holder) init(kind Any) {
	self.kind = kind
}

fn (self Holder) make_check() fn (Any) int {
	py2v_capture2 := &self
	check := fn [py2v_capture2] (value Any) int {
		if py2v_unsupported_dynamic_isinstance(value, (*py2v_capture2).kind) {
			return 1
		} else {
			return 0
		}
	}
	return check
}

pub fn py2v_new_holder(kind Any) Holder {
	mut py2v_instance := Holder{}
	py2v_instance.init(kind)
	return py2v_instance
}

pub struct Local {
}

fn direct(value Any, kind Any) bool {
	return py2v_unsupported_dynamic_isinstance(value, kind)
}

fn captured(b Any) fn (Any) int {
	py2v_capture1 := &b
	check := fn [py2v_capture1] (value Any) int {
		if py2v_unsupported_dynamic_isinstance(value, (*py2v_capture1)) {
			return 1
		}
		return 0
	}
	return check
}

fn tuple_types(value Any, kind Any) bool {
	return py2v_unsupported_dynamic_isinstance(value, [int, kind])
}

fn shadowed(value int, int_ Any) bool {
	return py2v_unsupported_dynamic_isinstance(value, int_)
}

fn static(value Any) bool {
	return value is Local
}

fn dynamic(value Any, types Any) bool {
	return py2v_unsupported_dynamic_isinstance(value, py2v_integer_generic_add1(types, [
		int,
		str,
	], 'dynamic_isinstance_bindings.py:43', |py2v_operand3, py2v_operand4| py2v_operand3 + py2v_operand4))
}

fn nested(value Any) bool {
	return py2v_unsupported_dynamic_isinstance(value, [int, [str, float]])
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
