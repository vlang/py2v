module main

import os

// TODO(py2v): 2 except handler(s) need a V Result equivalent:
//   except TypeError as eg (1 stmt)
//   except ValueError as eg (1 stmt)

fn handle() {
	panic('ExceptionGroup: ' + 'multiple')
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError as eg: 1 statement(s) need an `or { ... }` equivalent
	//   except TypeError as eg: 1 statement(s) need an `or { ... }` equivalent
}

fn main() {
	handle()
}
