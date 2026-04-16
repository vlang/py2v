@[translated]
module main

fn show() {
	// try: (V: wrap fallible calls below with `or {}`)
	3 / 0
	// except ZeroDivisionError:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	println('ZeroDivisionError')
}

fn main() {
	show()
}
