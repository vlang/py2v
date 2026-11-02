module main

// TODO(py2v): 2 except handler(s) need a V Result equivalent:
//   except (1 stmt)
//   except Exception as e (1 stmt)

fn show() {
	defer {
		println('Finally')
	}
	panic('Exception: ' + 'foo')
	// except handlers are not translated: see the TODO(py2v) note above
	//   except Exception as e: 1 statement(s) need an `or { ... }` equivalent
	panic('Exception: ' + 'foo')
	// except handlers are not translated: see the TODO(py2v) note above
	//   except: 1 statement(s) need an `or { ... }` equivalent
	panic('Exception: ' + 'foo')
	// except handlers are not translated: see the TODO(py2v) note above
	//   except Exception as e: 1 statement(s) need an `or { ... }` equivalent
}

fn main() {
	show()
}
