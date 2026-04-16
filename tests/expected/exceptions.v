@[translated]
module main

fn show() {
	defer {
		println('Finally')
	}
	// try: (V: wrap fallible calls below with `or {}`)
	panic('Exception: ' + 'foo')
	// except Exception as e:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	println('caught')
	// try: (V: wrap fallible calls below with `or {}`)
	panic('Exception: ' + 'foo')
	// except:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	println('Got it')
	// try: (V: wrap fallible calls below with `or {}`)
	panic('Exception: ' + 'foo')
	// except Exception as e:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	assert e.contains('foo')
}

fn main() {
	show()
}
