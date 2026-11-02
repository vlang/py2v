module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except ValueError (1 stmt)

fn from_try(flag bool) int {
	if !flag {
		panic('ValueError: ' + 'x')
	}
	mut result := 10
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError: 1 statement(s) need an `or { ... }` equivalent
	return result
}

fn main() {
	println(from_try(true))
	println(from_try(false))
}
