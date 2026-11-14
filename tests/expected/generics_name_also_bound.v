module main

interface Probe {
	ping() int
}

fn echo(item_type int) int {
	return item_type
}

fn main() {
	println(echo(7))
}
