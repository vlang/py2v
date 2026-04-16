@[translated]
module main

fn main_func() {
	fruits := ['apple', 'banana', 'cherry']
	for i, fruit in fruits {
		println(i)
		println(fruit)
	}
	names := ['Alice', 'Bob']
	ages := [25, 30]
	for __zipi1, name in names {
		age := ages[__zipi1]
		println(name)
		println(age)
	}
}

fn main() {
	main_func()
}
