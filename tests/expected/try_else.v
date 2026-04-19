module main

fn demo(ok bool) {
	defer {
		println('finally')
	}
	// try: (V: wrap fallible calls below with `or {}`)
	if !ok {
		panic('ValueError: ' + 'bad')
	}
	println('try')
	// else:
	// NOTE: runs only when try body has no exception in Python
	if false {
		println('else')
	}
	// except ValueError as e:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	println('except')
}

fn main() {
	demo(true)
	demo(false)
}
