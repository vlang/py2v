module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except ZeroDivisionError (1 stmt)

fn show() {
	py2v_true_div1(3, 0)
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ZeroDivisionError: 1 statement(s) need an `or { ... }` equivalent
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
}

fn main() {
	show()
}
