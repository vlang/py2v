module main

import pyrt
import strconv

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

fn twice(words []string) int {
	mut n := 0
	for w in words {
		if !true {
			// pass
		}
	}
	for w in words[..1] {
		n += py2v_text_length1(w)
	}
	return n
}

fn py2v_float_text1[T](value T) string {
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
	}
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn py2v_entry1() ! {
	println(highest_bit(25))
	println(rotate_py(3, 2)!)
	println(as_text_py(-7)!)
	println(if all_ints([1, 2, 3]) { 'True' } else { 'False' })
	println(count_ints_py([1, 0, 1])!)
	println(joined('-', ['a', 'b']))
	println(py2v_float_text1(scaled_py(1.5, 2)!))
	println(twice(['ab', 'c']))
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
