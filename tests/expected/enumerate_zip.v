@[translated]
module main

fn main_func() {
	fruits := ['apple', 'banana', 'cherry']
	for i, fruit in fruits {
		println(i.str())
		println(fruit.str())
	}
	names := ['Alice', 'Bob']
	ages := [25, 30]
	for __zipi1, name in names {
		age := ages[__zipi1]
		println(name.str())
		println(age.str())
	}
}

fn main() {
	main_func()
}
