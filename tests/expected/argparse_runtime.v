module main

import flag
import pyrt.argparse
import pyrt

fn build_py() !&argparse.ArgumentParser {
	parser := argparse.new_parser(prog: 'tool', description: 'Demo tool')
	parser.add_argument(['name'], help: 'who to greet')!
	parser.add_argument(['--count', '-c'],
		value_type:    .int_type
		default_value: pyrt.box(2)
		help:          'how many times'
	)!
	parser.add_argument(['--verbose'], action: 'store_true')!
	parser.add_argument(['--mode'],
		choices:       [pyrt.box('fast'), pyrt.box('slow')]
		default_value: pyrt.box('fast')
	)!
	parser.add_argument(['--tag'], action: 'append', default_value: pyrt.empty_list())!
	return parser
}

fn main_func_py() ! {
	parser := build_py()!
	args := parser.parse_args(['world', '--count', '3', '--verbose', '--tag', 'a', '--tag', 'b'])!
	py2v_range_stop1 := int(int(args.get_int('count')!))
	for _ in int(0) .. py2v_range_stop1 {
		println(('hello').str() + ' ' + (args.get_str('name')!).str())
	}
	if args.get_bool('verbose')! {
		println(('mode').str() + ' ' + (args.get_str('mode')!).str() + ' ' + ('tags').str() + ' ' + (args.get_strings('tag')!).str())
	}
	other := parser.parse_args(['x'])!
	println((int(other.get_int('count')!)).str() + ' ' + (if other.get_bool('verbose')! {
		'True'
	} else {
		'False'
	}).str() + ' ' + (other.get_str('mode')!).str() + ' ' + (other.get_strings('tag')!).str())
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
