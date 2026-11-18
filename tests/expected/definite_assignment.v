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
	return values.map(it + 1)
}

fn handlers() []int {
	mut values := []int{}
	values = [4]
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError: 1 statement(s) need an `or { ... }` equivalent
	return values.map(it + 1)
}

fn certain_loop() []int {
	mut values := []int{}
	for count in [6] {
		values = [count]
	}
	return values.map(it + 1)
}

fn terminating(enabled bool) []int {
	mut values := []int{}
	if enabled {
		return [8]
	} else {
		values = [9]
	}
	return values.map(it + 1)
}

fn while_break() []int {
	mut values := []int{}
	for {
		values = [10]
		break
	}
	return values.map(it + 1)
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
