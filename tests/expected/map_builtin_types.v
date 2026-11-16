module main

import arrays

fn parse(line string) []int {
	return line.split(' ').map(it.int())
}

fn halves(line string) []f64 {
	return line.split(',').map(it.f64())
}

fn texts(numbers []int) []string {
	return numbers.map(it.str())
}

fn whole(values []f64) []int {
	return values.map(int(it))
}

fn pair(line string) int {
	py2v_unpack1 := line.split(' ').map(it.int())
	mut a := py2v_unpack1[0]
	mut b := py2v_unpack1[1]
	return a * b
}

fn main() {
	println(parse('3 14 15'))
	println(arrays.sum(parse('1 2 3')) or { 0 })
	println(halves('1.5,2.25'))
	println(texts([1, 2, 3]))
	println(whole([1.9, 2.1]))
	println(pair('6 7'))
	println([4, 5].map(it.str()).join(' '))
	println(arrays.sum('1234'.split('').map(it.int())) or { 0 })
}
