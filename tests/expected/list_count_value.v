module main

fn or_gate(input_1 int, input_2 int) int {
	return int([input_1, input_2].count(it == 1) != 0)
}

fn zeros(a f64, b f64, c f64) int {
	return [a, b, c].count(it == 0)
}

fn main_func() {
	println(or_gate(0, 0))
	println(or_gate(1, 0))
	println(zeros(0, 2.5, 0))
	xs := [1, 2, 2, 3, 2]
	println(xs.count(it == 2))
	println([4, 4, 5].count(it == 4))
	names := ['a', 'b', 'a']
	println(names.count(it == 'a'))
	word := 'banana'
	println(word.count('a'))
	println('abcabc'.count('bc'))
}

fn main() {
	main_func()
}
