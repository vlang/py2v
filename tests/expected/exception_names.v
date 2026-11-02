module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except ZeroDivisionError (1 stmt)

fn show() {
	3 / 0
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ZeroDivisionError: 1 statement(s) need an `or { ... }` equivalent
}

fn main() {
	show()
}
