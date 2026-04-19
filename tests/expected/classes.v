module main

type Any = bool | int | i64 | f64 | string | []u8

// Foo is a simple test class.
//
// It has two methods: bar and baz.
pub struct Foo {
}

fn (self Foo) bar() Any {
	return self.baz()
}

fn (self Foo) baz() int {
	return 10
}

fn main() {
	f := Foo{}
	b := f.bar()
	println(b)
	assert b == 10
}
