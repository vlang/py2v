@[translated]

module main

fn greet(name string, greeting string) string {
	return greeting + ', ' + name + '!'
}

fn add(a int, b int) int {
	return a + b
}

fn main_func() {
	println(greet('Alice', 'Hello'))
	println(greet('Bob', 'Hi'))
	println(add(5, 10))
	println(add(5, 20))
}

fn main() {
	main_func()
}
