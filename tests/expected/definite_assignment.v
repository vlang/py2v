module main

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except ValueError (1 stmt)

fn branches(enabled bool) []int {
	mut values := []int{}
	if enabled {
		values = [1, 2]
	} else {
		values = [3]
	}
	return values.map(py2v_integer_add1(it, 1, 'definite_assignment.py:6', 'addition'))
}

fn handlers() []int {
	mut values := []int{}
	values = [4]
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError: 1 statement(s) need an `or { ... }` equivalent
	return values.map(py2v_integer_add1(it, 1, 'definite_assignment.py:14', 'addition'))
}

fn certain_loop() []int {
	mut values := []int{}
	for count in [6] {
		values = [count]
	}
	return values.map(py2v_integer_add1(it, 1, 'definite_assignment.py:20', 'addition'))
}

fn terminating(enabled bool) []int {
	mut values := []int{}
	if enabled {
		return [8]
	} else {
		values = [9]
	}
	return values.map(py2v_integer_add1(it, 1, 'definite_assignment.py:28', 'addition'))
}

fn while_break() []int {
	mut values := []int{}
	for {
		values = [10]
		break
	}
	return values.map(py2v_integer_add1(it, 1, 'definite_assignment.py:35', 'addition'))
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	println(branches(true))
	println(branches(false))
	println(handlers())
	println(certain_loop())
	println(terminating(true))
	println(terminating(false))
	println(while_break())
}
