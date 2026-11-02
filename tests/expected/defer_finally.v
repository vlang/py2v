module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except ValueError as e (1 stmt)

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
	value := '123'.int()
	println(value)
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError as e: 1 statement(s) need an `or { ... }` equivalent
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
	println(pure_finally())
	println(nested_finally())
	mixed_handlers()
	multi_stmt_finally()
}
