@[translated]
module main

fn pure_finally() int {
	mut result := 0
	defer {
		println('cleanup')
	}
	result = 42
	return result
}

fn nested_finally() int {
	defer {
		println('outer cleanup')
	}
	defer {
		println('inner cleanup')
	}
	x := 10
	return x
}

fn mixed_handlers() {
	defer {
		println('done')
	}
	// try {
	value := '123'.int()
	println(value.str())
	// } catch {
	// except ValueError:
	// NOTE: V uses Result types (!) and or{} blocks instead of exceptions
	// println('bad value')
	// }
}

fn multi_stmt_finally() {
	mut resource := none
	defer {
		println('step 1')
		println('step 2')
		resource = none
	}
	resource = 1
}

fn main() {
	println((pure_finally()).str())
	println((nested_finally()).str())
	mixed_handlers()
	multi_stmt_finally()
}
