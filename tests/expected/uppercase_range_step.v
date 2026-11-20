module main

fn count() {
	d := 2
	for r := 0; r < 5; r += d {
		println(r)
	}
}

fn main() {
	count()
}
