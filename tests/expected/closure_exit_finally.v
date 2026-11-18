module main

import pyrt

fn inner() int {
	defer {
		println('inner cleanup')
	}
	return 7
}

fn define_in_finally() int {
	defer {
		// pass
		println(inner())
	}
	return 5
}

fn exit_later() {
	println('inner exit')
	pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.box(0)])))
}

fn make_exit() fn () {
	defer {
		println('outer cleanup')
	}
	// pass
	return exit_later
}

fn main() {
	println(define_in_finally())
	delayed_exit := make_exit()
	delayed_exit()
}
