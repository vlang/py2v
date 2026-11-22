module main

import strconv
import strings

fn count_ones(a int) int {
	return py2v_bin1(i64(a)).count('1')
}

fn bits(number int) string {
	return if py2v_slice_step1(py2v_bin1(i64(number)).runes(), 2, ?int(none), 1).string().len < 8 {
		strings.repeat(`0`, 8 - py2v_slice_step1(py2v_bin1(i64(number)).runes(), 2, ?int(none), 1).string().len) + py2v_slice_step1(py2v_bin1(i64(number)).runes(), 2, ?int(none), 1).string()
	} else {
		py2v_slice_step1(py2v_bin1(i64(number)).runes(), 2, ?int(none), 1).string()
	}
}

fn main_func() {
	println(py2v_bin1(i64(5)))
	println(py2v_bin1(i64(0)))
	println(py2v_bin1(i64(-5)))
	n := 37
	println(py2v_bin1(i64(n)))
	println(py2v_slice_step1((py2v_bin1(i64(n))).str().runes(), 2, ?int(none), 1).string())
	println(count_ones(255))
	println(bits(10))
	println(py2v_text_length1(py2v_bin1(i64(1 << 10))))
	table := []int{len: 8, init: index}.map(py2v_bin1(i64(it)).count('1'))
	println(table)
}

fn py2v_bin1(n i64) string {
	if n < 0 {
		return '-0b' + strconv.format_uint(u64(-(n + 1)) + 1, 2)
	}
	return '0b' + strconv.format_int(n, 2)
}

fn py2v_slice_step1[T](values []T, lower ?int, upper ?int, step int) []T {
	if step == 0 {
		panic('ValueError: slice step cannot be zero')
	}
	n := values.len
	min_index := if step < 0 { -1 } else { 0 }
	max_index := if step < 0 { n - 1 } else { n }
	mut start := if step < 0 { max_index } else { min_index }
	mut stop := if step < 0 { min_index } else { max_index }
	if bound := lower {
		offset := if bound < 0 { bound + n } else { bound }
		start = if offset < min_index {
			min_index
		} else if offset > max_index {
			max_index
		} else {
			offset
		}
	}
	if bound := upper {
		offset := if bound < 0 { bound + n } else { bound }
		stop = if offset < min_index {
			min_index
		} else if offset > max_index {
			max_index
		} else {
			offset
		}
	}
	mut result := []T{}
	for index := start; if step < 0 { index > stop } else { index < stop }; index += step {
		result << values[index]
		if (step < 0 && step <= stop - index) || (step > 0 && step >= stop - index) {
			break
		}
	}
	return result
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	main_func()
}
