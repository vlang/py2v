module main

import strconv
import strings

fn count_ones(a int) int {
	return py2v_bin1(i64(a)).count('1')
}

fn bits(number int) string {
	return if py2v_bin1(i64(number))[2..].len < 8 {
		strings.repeat(`0`, 8 - py2v_bin1(i64(number))[2..].len) + py2v_bin1(i64(number))[2..]
	} else {
		py2v_bin1(i64(number))[2..]
	}
}

fn main_func() {
	println(py2v_bin1(i64(5)))
	println(py2v_bin1(i64(0)))
	println(py2v_bin1(i64(-5)))
	n := 37
	println(py2v_bin1(i64(n)))
	println((py2v_bin1(i64(n))).str()[2..])
	println(count_ones(255))
	println(bits(10))
	println(py2v_bin1(i64(1 << 10)).len)
	table := []int{len: 8, init: index}.map(py2v_bin1(i64(it)).count('1'))
	println(table)
}

fn py2v_bin1(n i64) string {
	if n < 0 {
		return '-0b' + strconv.format_int(-n, 2)
	}
	return '0b' + strconv.format_int(n, 2)
}

fn main() {
	main_func()
}
