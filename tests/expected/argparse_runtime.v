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

fn build() &argparse.ArgumentParser {
	return build_py() or { pyrt.fail(err) }
}

fn main_func_py() ! {
	parser := build_py()!
	args := parser.parse_args(['world', '--count', '3', '--verbose', '--tag', 'a', '--tag', 'b'])!
	py2v_range_start1 := 0
	py2v_range_stop2 := int(args.get_int('count')!)
	py2v_range_step3 := 1
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for py2v_range_item4 := py2v_range_start1; if py2v_range_step3 > 0 {
		py2v_range_item4 < py2v_range_stop2
	} else {
		py2v_range_item4 > py2v_range_stop2
	}; py2v_range_item4 = py2v_range_next1(py2v_range_item4, py2v_range_stop2, py2v_range_step3) {
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

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}

fn main() {
	main_func()
}
