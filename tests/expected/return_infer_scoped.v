module main

fn from_try(flag bool) int {
	// try: (V: wrap fallible calls below with `or {}`)
	if !flag {
		panic('ValueError: ' + 'x')
	}
	mut result := 10
	// except ValueError:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	result = 20
	return result
}

fn main() {
	println(from_try(true))
	println(from_try(false))
}
