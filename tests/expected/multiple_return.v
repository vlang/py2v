module main

fn get_pair() []int {
	return [1, 2]
}

fn get_triple() []int {
	return [10, 20, 30]
}

fn divmod_custom(a int, b int) []int {
	return [py2v_integer_floor_div1(a, b, 'multiple_return.py:10'),
		py2v_integer_mod1(a, b, 'multiple_return.py:10')]
}

fn main_func() {
	py2v_unpack1 := get_pair()
	mut x := py2v_unpack1[0]
	mut y := py2v_unpack1[1]
	println(x)
	println(y)
	py2v_unpack2 := get_triple()
	mut a := py2v_unpack2[0]
	mut b := py2v_unpack2[1]
	mut c := py2v_unpack2[2]
	println(a)
	println(b)
	println(c)
	py2v_unpack3 := divmod_custom(17, 5)
	mut quotient := py2v_unpack3[0]
	mut remainder := py2v_unpack3[1]
	println(quotient)
	println(remainder)
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_floor_div1(a int, b int, site string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	if b == -1 && a == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'floor division') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
}

fn main() {
	main_func()
}
