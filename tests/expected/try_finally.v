module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except (1 stmt)

fn with_finally(x int) int {
	mut result := 0
	defer {
		println('finally executed')
	}
	result = x * 2
	return result
}

fn main_func() {
	println(with_finally(5))
	println(with_finally(10))
	defer {
		println('cleanup')
	}
	x := 10
	println(x)
	// except handlers are not translated: see the TODO(py2v) note above
	//   except: 1 statement(s) need an `or { ... }` equivalent
}

fn main() {
	main_func()
}
