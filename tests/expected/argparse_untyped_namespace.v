module main

import flag
import pyrt.argparse
import pyrt

fn cmd_list(args argparse.Namespace) int {
	println(('list').str() + ' ' + (int(args.get_int('limit') or { pyrt.fail(err) })).str() + ' ' + (if args.get_bool('verbose') or { pyrt.fail(err) } {
		'True'
	} else {
		'False'
	}).str())
	if pyrt.truth(args.require('name') or { pyrt.fail(err) }) {
		println(('name').str() + ' ' + (pyrt.str(args.require('name') or { pyrt.fail(err) })).str())
	}
	return 0
}

fn cmd_add(args argparse.Namespace) int {
	total := int(args.get_int('limit') or { pyrt.fail(err) }) + 1
	println(('add').str() + ' ' + (args.get_str('item') or { pyrt.fail(err) }).str() + ' ' + total.str())
	return 0
}

fn main_func_py(argv []string) !int {
	parser := argparse.new_parser(prog: 'tool')
	parser.add_argument(['--limit'], value_type: .int_type, default_value: pyrt.box(5))!
	parser.add_argument(['--verbose'], action: 'store_true')!
	parser.add_argument(['--name'])!
	parser.add_argument(['item'])!
	args := parser.parse_args(argv)!
	if args.get_bool('verbose') or { pyrt.fail(err) } {
		return cmd_list(args)
	}
	return cmd_add(args)
}

fn main_func(argv []string) int {
	return main_func_py(argv) or { pyrt.fail(err) }
}

fn main() {
	main_func(['thing', '--limit', '2'])
	main_func(['thing', '--verbose', '--name', 'n'])
}
