@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

pub struct Animal {
}

pub struct Dog {
	Animal
}

pub struct Cat {
	Animal
}

pub struct Bird {
	Animal
}

fn check_single(x Any) bool {
	return x is Dog
}

fn check_tuple(x Any) bool {
	return x is Dog || x is Cat
}

fn check_triple(x Any) bool {
	return x is Dog || x is Cat || x is Bird
}

fn check_in_if(x Any) {
	if (x is Dog || x is Cat) {
		println('pet')
	} else {
		println('other')
	}
}

fn check_negated(x Any) bool {
	return !(x is Dog || x is Cat)
}

fn main() {
	d := Dog{}
	println(if check_single(d) { 'True' } else { 'False' })
	println(if check_tuple(d) { 'True' } else { 'False' })
	println(if check_triple(d) { 'True' } else { 'False' })
	check_in_if(d)
	println(if check_negated(d) { 'True' } else { 'False' })
}
