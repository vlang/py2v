module main

fn pair(value int) (int, string) {
	return value, 'ready'
}

fn main() {
	number, message := pair(7)
	println('${number} ${message}')
}
