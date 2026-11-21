module main

import flag
import pyrt.argparse
import pyrt

fn add_run_py(subparsers &argparse.Subparsers) ! {
	run := subparsers.add_parser('run', help: 'Run a task')!
	run.add_argument(['name'])!
}

fn add_nested_py(subparsers &argparse.Subparsers) ! {
	parent := subparsers.add_parser('group', help: 'Grouped tasks')!
	children := parent.add_subparsers(dest: 'child', required: true)!
	leaf := children.add_parser('leaf')!
	leaf.add_argument(['--count'], value_type: .int_type, default_value: pyrt.box(2))!
}

fn main_func_py() ! {
	parser := argparse.new_parser(prog: 'builder-test')
	commands := parser.add_subparsers(dest: 'command', required: true)!
	add_run_py(commands)!
	add_nested_py(commands)!
	args := parser.parse_args(['run', 'Ada'])!
	println((pyrt.str(args.require('command')!)).str() + ' ' + (args.get_str('name')!).str())
	nested := parser.parse_args(['group', 'leaf', '--count', '3'])!
	println((pyrt.str(nested.require('command')!)).str() + ' ' + (pyrt.str(nested.require('child')!)).str() + ' ' + (int(nested.get_int('count')!)).str())
	defaults := parser.parse_args(['group', 'leaf'])!
	println(int(defaults.get_int('count')!))
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
