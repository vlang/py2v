module main

fn is_even(n int) bool {
	return n % 2 == 0
}

fn describe(n int) string {
	even := is_even(n)
	if even {
		println(if even { 'True' } else { 'False' })
		return 'even'
	}
	println(if even { 'True' } else { 'False' })
	return 'odd'
}

fn main() {
	println(describe(4))
	println(describe(7))
}
