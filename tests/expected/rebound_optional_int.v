module main

fn number(mut value ?int) {
	if value == none {
		value = 7
	}
	if value != none {
		println(value)
	}
}

fn main() {
	number(none)
	number(mut 1.0)
}
