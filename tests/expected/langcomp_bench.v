@[translated]
module main

fn test_python(iterations int) {
	mut iteration := 0
	mut total := f64(0)
	array_length := 1000
	array := []int{len: array_length, init: index}.map(it)
	println('iterations' + ' ' + iterations.str())
	for iteration < iterations {
		mut innerloop := 0
		for innerloop < 100 {
			total += array[((iteration + innerloop) % array_length)]
			innerloop += 1
		}
		iteration += 1
	}
	if total == 15150 {
		println('OK')
	}

	// del array - V does not support deleting variables
}

fn main() {
	test_python(3)
}
