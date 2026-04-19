module main

fn handle(flag bool) {
	// WARNING: except* (ExceptionGroup) is not supported in V.
	// Translate each except* handler manually using goroutines or error unions.
	// try: (V: wrap fallible calls below with `or {}`)
	// except* synthesized dispatch for literal ExceptionGroup
	if flag {
		panic('ExceptionGroup: ' + 'mixed')
	}
	println('no raise')
	// except ValueError as eg:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	// NOTE: matched synthetic ExceptionGroup member type(s): ValueError
	println('caught value')
	// except TypeError as eg:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	// NOTE: matched synthetic ExceptionGroup member type(s): TypeError
	println('caught type')
}

fn main() {
	handle(true)
	handle(false)
}
