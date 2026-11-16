module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn sum_all(nums ...Any) int {
	mut total := 0
	for n in nums {
		total += n
	}
	return total
}

fn main_func() {
	println('a'.repeat(5))
	println([0].repeat(3))
	numbers := [1, 2, 3]
	println(sum_all(...numbers))
	others := [4, 5]
	all_nums := ((([0]).concat(numbers)).concat(others)).concat([6])
	println(all_nums)
	data := [10, 20, 30, 40, 50]
	py2v_unpack1 := data
	mut a := py2v_unpack1[0]
	mut rest := py2v_unpack1[1..py2v_unpack1.len - 1]
	mut e := py2v_unpack1.last()
	println(a)
	println(rest)
	println(e)
}

fn main() {
	main_func()
}
