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

pub struct Args {
pub mut:
	a_bin string
	only  []Any
}

fn (mut self Args) init() {
	self.a_bin = 'x'
	self.only = []Any{}
}

pub fn py2v_new_args() Args {
	mut py2v_instance := Args{}
	py2v_instance.init()
	return py2v_instance
}

fn main() {
	originals := ['a']
	args := py2v_new_args()
	selected := args.only || originals.filter(py2v_unsupported_getattr_by_computed_name(args, '${it}_bin')).map(it)
	println((args.a_bin).str() + ' ' + (if (typeof(args.only).name != '') {
		'True'
	} else {
		'False'
	}).str())
	name := 'a_bin'
	py2v_unsupported_setattr_by_computed_name(args, name, 'y')
	println(py2v_unsupported_getattr_by_computed_name(args, name, none))
}
