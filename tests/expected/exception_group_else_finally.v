module main

// TODO(py2v): 2 except handler(s) need a V Result equivalent:
//   else clause (1 stmt)
//   except ValueError as eg (1 stmt)

fn handle(ok bool) {
	defer {
		println('cleanup')
	}
	if ok {
		println('ok')
	} else {
		panic('ExceptionGroup: ' + 'eg')
	}
	// else: runs only when the try body raises, which no V construct here does
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError as eg: 1 statement(s) need an `or { ... }` equivalent
}

fn main() {
	handle(true)
	handle(false)
}
