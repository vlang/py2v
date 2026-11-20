module main

const @volatile = 4

fn number() int {
	return @volatile
}

fn main() {
	println(number())
}
