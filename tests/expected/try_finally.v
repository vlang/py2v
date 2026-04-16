@[translated]
module main

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
	// try: (V: wrap fallible calls below with `or {}`)
	x := 10
	println(x)
	// except:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	println('error')
}

fn main() {
	main_func()
}
