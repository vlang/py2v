module main

fn f(x int) int {
	if x < 0 {
		panic('ValueError: ' + 'negative')
	}
	return x
}

fn f_py(x int) int {
	return x * 2
}

fn main() {
	println('${f(2)} ${f_py(2)}')
}
