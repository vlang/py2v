module main

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

fn make_exit() fn () {
	defer {
		println('outer cleanup')
	}
	exit_later := fn () {
		println('inner exit')
		exit(0)
	}
	return exit_later
}

fn main() {
	println(define_in_finally())
	delayed_exit := make_exit()
	delayed_exit()
}
