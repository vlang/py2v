module main

import pyrt

// TODO(py2v): no V equivalent for import py2v_fixture_missing_dependency
// Provide one in python_to_v_import (types.v) or port the module.

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except ImportError (1 stmt)

type Any = pyrt.Value

pub struct Wrapper {
pub mut:
	value Any
}

fn from_context_py(value Any) !string {
	return pyrt.to_str(pyrt.call_method(pyrt.box(value), 'upper', [])!)
}

fn from_context(value Any) string {
	return from_context_py(value) or { pyrt.fail(err) }
}

fn lookup_py() !Any {
	return pyrt.untranslated_import('py2v_fixture_missing_dependency.make')!
}

fn lookup() Any {
	return lookup_py() or { pyrt.fail(err) }
}

fn main() {

	// except handlers are not translated: see the TODO(py2v) note above
	//   except ImportError: 1 statement(s) need an `or { ... }` equivalent
	println(from_context('ready'))
}
