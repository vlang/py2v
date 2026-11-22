module main

import flag
import pyrt.argparse
import pyrt

fn cmd_list_py(args argparse.Namespace) !int {
	println(('list').str() + ' ' + (int(args.get_int('limit')!)).str() + ' ' + (if args.get_bool('verbose')! {
		'True'
	} else {
		'False'
	}).str())
	if pyrt.truth(args.require('name')!) {
		println(('name').str() + ' ' + (pyrt.str(args.require('name')!)).str())
	}
	return 0
}

fn cmd_add_py(args argparse.Namespace) !int {
	total := py2v_integer_add1(int(args.get_int('limit')!), 1, 'argparse_untyped_namespace.py:13', 'addition')
	println(('add').str() + ' ' + (args.get_str('item')!).str() + ' ' + total.str())
	return 0
}

fn main_func_py(argv []string) !int {
	parser := argparse.new_parser(prog: 'tool')
	parser.add_argument(['--limit'], value_type: .int_type, default_value: pyrt.box(5))!
	parser.add_argument(['--verbose'], action: 'store_true')!
	parser.add_argument(['--name'])!
	parser.add_argument(['item'])!
	args := parser.parse_args(argv)!
	if args.get_bool('verbose')! {
		return cmd_list_py(args)!
	}
	return cmd_add_py(args)!
}

fn py2v_entry1() ! {
	main_func_py(['thing', '--limit', '2'])!
	main_func_py(['thing', '--verbose', '--name', 'n'])!
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

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
