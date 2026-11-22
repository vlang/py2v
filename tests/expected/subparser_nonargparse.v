module main

import flag
import pyrt
import pyrt.argparse

type Any = pyrt.Value

pub struct CustomBuilder {
}

fn (self CustomBuilder) add_parser(name string) string {
	return 'custom:' + name
}

fn add_custom_py(builder Any) !Any {
	return pyrt.call(pyrt.getattr(pyrt.box(builder), 'add_parser')!, [pyrt.box('x')])!
}

fn add_real_py(subparsers &argparse.Subparsers) ! {
	subparsers.add_parser('real')!
}

fn exercise_py() ! {
	parser := argparse.new_parser()
	action := parser.add_subparsers(dest: 'command')!
	add_real_py(action)!
	println(pyrt.str(add_custom_py(CustomBuilder{})!))
}

fn py2v_entry1() ! {
	exercise_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
