module main

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
