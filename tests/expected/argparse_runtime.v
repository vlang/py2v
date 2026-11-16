module main

import flag
import pyrt.argparse
import pyrt

fn build() &argparse.ArgumentParser {
	parser := argparse.new_parser(prog: 'tool', description: 'Demo tool')
	parser.add_argument(['name'], help: 'who to greet') or { pyrt.fail(err) }
	parser.add_argument(['--count', '-c'],
		value_type:    .int_type
		default_value: pyrt.box(2)
		help:          'how many times'
	) or { pyrt.fail(err) }
	parser.add_argument(['--verbose'], action: 'store_true') or { pyrt.fail(err) }
	parser.add_argument(['--mode'],
		choices:       [pyrt.box('fast'), pyrt.box('slow')]
		default_value: pyrt.box('fast')
	) or { pyrt.fail(err) }
	parser.add_argument(['--tag'], action: 'append', default_value: pyrt.empty_list()) or { pyrt.fail(err) }
	return parser
}

fn main_func() {
	parser := build()
	args := parser.parse_args(['world', '--count', '3', '--verbose', '--tag', 'a', '--tag', 'b']) or { pyrt.fail(err) }
	for _ in []int{len: int(args.get_int('count') or { pyrt.fail(err) }), init: index} {
		println(('hello').str() + ' ' + (args.get_str('name') or { pyrt.fail(err) }).str())
	}
	if args.get_bool('verbose') or { pyrt.fail(err) } {
		println(('mode').str() + ' ' + (args.get_str('mode') or { pyrt.fail(err) }).str() + ' ' + ('tags').str() + ' ' + (args.get_strings('tag') or { pyrt.fail(err) }).str())
	}
	other := parser.parse_args(['x']) or { pyrt.fail(err) }
	println((int(other.get_int('count') or { pyrt.fail(err) })).str() + ' ' + (if other.get_bool('verbose') or { pyrt.fail(err) } {
		'True'
	} else {
		'False'
	}).str() + ' ' + (other.get_str('mode') or { pyrt.fail(err) }).str() + ' ' + (other.get_strings('tag') or { pyrt.fail(err) }).str())
}

fn main() {
	main_func()
}
