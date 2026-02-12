@[translated]
module main

// Foo is a simple test class.
//
// It has two methods: bar and baz.
pub struct Foo {
}

fn (self Foo) bar() int {
	return self.baz()
}

fn (self Foo) baz() int {
	return 10
}

fn main() {
	f := Foo{}
	b := f.bar()
	println(b.str())
	assert b == 10
}
