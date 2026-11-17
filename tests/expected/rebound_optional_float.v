module main

fn fraction(mut value ?f64) {
	if value == none {
		value = 1.5
	}
	if value != none {
		println(value)
	}
}

fn main() {
	fraction(none)
	fraction(mut 3)
}
