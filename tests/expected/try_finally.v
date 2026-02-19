@[translated]
module main

fn with_finally(x int) int {
	mut result := 0
	defer {
		println('finally executed')
	}
	result = (x * 2)
	return result
}

fn main_func() {
	println((with_finally(5)).str())
	println((with_finally(10)).str())
	defer {
		println('cleanup')
	}
	// try {
	x := 10
	println(x.str())
	// } catch {
	// except:
	// NOTE: V uses Result types (!) and or{} blocks instead of exceptions
	// println('error')
	// }
}

fn main() {
	main_func()
}
