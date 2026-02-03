@[translated]
module main

fn main_func() {
	fruits := ['apple', 'banana', 'cherry']
	for [i, fruit] in fruits /* enumerate is usually used in for loops in V */ {
		println(i.str())
		println(fruit.str())
	}
	names := ['Alice', 'Bob']
	ages := [25, 30]
	for [name, age] in /* zip(names, ages) not fully supported as expression */ {
		println(name.str())
		println(age.str())
	}
}

fn main() {
	main_func()
}
