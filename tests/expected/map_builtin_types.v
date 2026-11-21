module main

import arrays

fn parse(line string) []int {
	return py2v_split_whitespace1(line).map(it.int()).clone()
}

fn halves(line string) []f64 {
	return line.split(',').map(it.f64()).clone()
}

fn texts(numbers []int) []string {
	return numbers.map(it.str()).clone()
}

fn whole(values []f64) []int {
	return values.map(int(it)).clone()
}

fn pair(line string) int {
	py2v_unpack1 := py2v_split_whitespace1(line).map(it.int())
	mut a := py2v_unpack1[0]
	mut b := py2v_unpack1[1]
	return a * b
}

fn py2v_split_whitespace1(value string) []string {
	return value.split_any(' \t\n\r\u000b\u000c\u001c\u001d\u001e\u001f\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000').filter(it != '')
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
