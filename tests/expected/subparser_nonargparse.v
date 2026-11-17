module main

import flag
import pyrt
import pyrt.argparse

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

pub struct CustomBuilder {
}

fn (self CustomBuilder) add_parser(name string) string {
	return 'custom:' + name
}

fn add_custom_py(builder Any) !Any {
	return pyrt.call(pyrt.getattr(pyrt.box(builder), 'add_parser')!, [pyrt.box('x')])!
}

fn add_custom(builder Any) Any {
	return add_custom_py(builder) or { pyrt.fail(err) }
}

fn add_real_py(subparsers &argparse.Subparsers) ! {
	subparsers.add_parser('real')!
}

fn add_real(subparsers &argparse.Subparsers) {
	add_real_py(subparsers) or { pyrt.fail(err) }
}

fn exercise_py() ! {
	parser := argparse.new_parser()
	action := parser.add_subparsers(dest: 'command')!
	add_real_py(action)!
	println(pyrt.str(add_custom_py(CustomBuilder{})!))
}

fn exercise() {
	exercise_py() or { pyrt.fail(err) }
}

fn main() {
	exercise()
}
