module main

import os

fn handle() {
	// WARNING: except* (ExceptionGroup) is not supported in V.
	// Translate each except* handler manually using goroutines or error unions.
	// try: (V: wrap fallible calls below with `or {}`)
	// except* synthesized dispatch for literal ExceptionGroup
	panic('ExceptionGroup: ' + 'multiple')
	// except ValueError as eg:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	// NOTE: matched synthetic ExceptionGroup member type(s): ValueError
	println('caught value error group')
	// except TypeError as eg:
	// NOTE: V uses Result types; adapt body to use `or { ... }` blocks
	// NOTE: matched synthetic ExceptionGroup member type(s): TypeError
	println('caught type error group')
}

fn main() {
	handle()
}
