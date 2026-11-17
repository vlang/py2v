module main

import pyrt

fn define_in_finally() int {
	defer {
		inner := fn () int {
			defer {
				println('inner cleanup')
			}
			return 7
		}
		println(inner())
	}
	return 5
}

fn make_exit() fn () {
	defer {
		println('outer cleanup')
	}
	exit_later := fn () {
		println('inner exit')
		pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.box(0)])))
	}
	return exit_later
}

fn main() {
	println(define_in_finally())
	delayed_exit := make_exit()
	delayed_exit()
}
