module main

fn handle(ok bool) {
	// WARNING: except* (ExceptionGroup) is not supported in V.
	// Translate each except* handler manually using goroutines or error unions.
	defer {
		println('cleanup')
	}
	// try: (V: wrap fallible calls below with `or {}`)
	// except* synthesized dispatch for literal ExceptionGroup
	if ok {
		println('ok')
	} else {
		panic('ExceptionGroup: ' + 'eg')
	}
	// else:
	// NOTE: runs only when try body has no exception in Python
	if false {
		println('no group')
	}
	// except ValueError as eg:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	// NOTE: matched synthetic ExceptionGroup member type(s): ValueError
	println('caught value group')
}

fn main() {
	handle(true)
	handle(false)
}
