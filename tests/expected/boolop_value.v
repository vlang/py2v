module main

pub struct Cipher {
pub mut:
	key int
}

fn (mut self Cipher) init(key int) {
	self.key = key
}

fn (self Cipher) shift(value int, py2v_key_in1 int) int {
	mut key := py2v_key_in1
	key = if key != 0 {
		key
	} else {
		if self.key != 0 { self.key } else { 1 }
	}
	return value + key
}

pub fn py2v_new_cipher(key int) Cipher {
	mut py2v_instance := Cipher{}
	py2v_instance.init(key)
	return py2v_instance
}

fn greeting(given string) string {
	name := if given != '' { given } else { 'world' }
	return 'hello ' + name
}

fn first_items(given []int) []int {
	items := if given.len > 0 { given } else { [0] }
	return items
}

fn both(a int, b int) int {
	return if a != 0 { b } else { a }
}

fn neither(a int, b int) bool {
	return !(a != 0 && b != 0)
}

fn main_func() {
	println(greeting(''))
	println(greeting('you'))
	println(py2v_new_cipher(0).shift(1, 0))
	println(py2v_new_cipher(5).shift(1, 0))
	println(py2v_new_cipher(5).shift(1, 2))
	println(first_items([]).len)
	println(first_items([4, 5]).len)
	println(both(0, 3))
	println(both(2, 3))
	println(if neither(1, 1) { 'True' } else { 'False' })
	println(if neither(1, 0) { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
