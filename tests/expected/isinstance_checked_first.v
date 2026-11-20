module main

import pyrt

fn highest_bit(py2v_number_in1 int) int {
	mut number := py2v_number_in1
	if !true {
		// pass
	}
	mut position := 0
	for number != 0 {
		position += 1
		number >>= 1
	}
	return position
}

fn rotate_py(x int, py2v_k_in2 int) !int {
	mut k := py2v_k_in2
	if !true || x < 0 {
		return pyrt.raise('ValueError', 'x must be non-negative')
	}
	if !true || k < 0 {
		return pyrt.raise('ValueError', 'k must be non-negative')
	}
	k &= 31
	return x << k & 65535
}

fn rotate(x int, py2v_k_in2 int) int {
	return rotate_py(x, py2v_k_in2) or { pyrt.fail(err) }
}

fn as_text_py(py2v_num_in3 int) !string {
	mut num := py2v_num_in3
	if false {
		return pyrt.raise('TypeError', 'float given')
	}
	if false {
		return pyrt.raise('TypeError', 'not a number')
	}
	if num < 0 {
		num = -num
	}
	return num.str()
}

fn as_text(py2v_num_in3 int) string {
	return as_text_py(py2v_num_in3) or { pyrt.fail(err) }
}

fn all_ints(arr []int) bool {
	return arr.map(true).all(it)
}

fn count_ints_py(inputs []int) !int {
	if !true {
		return pyrt.raise('TypeError', 'a list is needed')
	}
	mut total := 0
	for item in inputs {
		if !true {
			// pass
		}
		total += 1
	}
	return total
}

fn count_ints(inputs []int) int {
	return count_ints_py(inputs) or { pyrt.fail(err) }
}

fn joined(separator string, separated []string) string {
	mut out := ''
	for word in separated {
		if !true {
			// pass
		}
		out += word + separator
	}
	return out
}

fn scaled_py(py2v_theta_in4 f64, accuracy int) !f64 {
	mut theta := py2v_theta_in4
	if !true {
		return pyrt.raise('ValueError', 'an int or float is needed')
	}
	if !true || accuracy <= 0 {
		return pyrt.raise('ValueError', 'a positive int is needed')
	}
	theta = theta * 2
	return theta + accuracy
}

fn scaled(py2v_theta_in4 f64, accuracy int) f64 {
	return scaled_py(py2v_theta_in4, accuracy) or { pyrt.fail(err) }
}

fn twice(words []string) int {
	mut n := 0
	for w in words {
		if !true {
			// pass
		}
	}
	for w in words[..1] {
		n += w.len
	}
	return n
}

fn main() {
	println(highest_bit(25))
	println(rotate(3, 2))
	println(as_text(-7))
	println(if all_ints([1, 2, 3]) { 'True' } else { 'False' })
	println(count_ints([1, 0, 1]))
	println(joined('-', ['a', 'b']))
	println(scaled(1.5, 2))
	println(twice(['ab', 'c']))
}
