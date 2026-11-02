module main

// TODO(py2v): 2 except handler(s) need a V Result equivalent:
//   else clause (1 stmt)
//   except ValueError as e (1 stmt)

fn demo(ok bool) {
	defer {
		println('finally')
	}
	if !ok {
		panic('ValueError: ' + 'bad')
	}
	println('try')
	// else: runs only when the try body raises, which no V construct here does
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError as e: 1 statement(s) need an `or { ... }` equivalent
}

fn main() {
	demo(true)
	demo(false)
}
