module main

fn value() int {
	println(7)
	return 3
}

fn py2v_isinstance_empty1[T](value T) bool {
	_ = value
	return false
}

fn main() {
	println(if py2v_isinstance_empty1(value()) { 'True' } else { 'False' })
}
