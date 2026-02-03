@[translated]
module main

fn with_finally(x int) int {
	mut result := 0
	// try {
	result = (x * 2)
	// } catch {
	// finally:
	println('finally executed')
	// }
	return result
}

fn main_func() {
	println((with_finally(5)).str())
	println((with_finally(10)).str())
	// try {
	x := 10
	println(x.str())
	// } catch {
	// except:
	// NOTE: V does not have exception handling - this code is unreachable
	// println('error')
	// finally:
	println('cleanup')
	// }
}

fn main() {
	main_func()
}
