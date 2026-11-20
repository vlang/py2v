module main

import strconv

pub struct Counter {
pub mut:
	total int
}

fn (mut self Counter) init() {
	self.total = 0
}

fn (mut self Counter) add(py2v_amount_in5 int) int {
	mut amount := py2v_amount_in5
	if amount < 0 {
		amount = 0
	}
	self.total += amount
	return self.total
}

pub fn py2v_new_counter() Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init()
	return py2v_instance
}

fn countdown(py2v_n_in1 int) int {
	mut n := py2v_n_in1
	mut steps := 0
	for n > 0 {
		n -= 1
		steps += 1
	}
	return steps
}

fn shout(py2v_text_in2 string, py2v_times_in3 int) string {
	mut text := py2v_text_in2
	mut times := py2v_times_in3
	text = text.to_upper()
	for times > 1 {
		text += '!'
		times -= 1
	}
	return text
}

fn clamp(py2v_x_in4 f64, lo f64) f64 {
	mut x := py2v_x_in4
	if x < lo {
		x = lo
	}
	return x
}

fn py2v_float_text1(value f64) string {
	scientific := strconv.f64_to_str(value, 16)
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
}

fn main() {
	value := 3
	println(countdown(value))
	println(value)
	println(shout('hi', 3))
	println(py2v_float_text1(f64(clamp(-1.5, 0.0))))
	println(py2v_float_text1(f64(clamp(2.5, 0.0))))
	mut c := py2v_new_counter()
	println(c.add(-4))
	println(c.add(5))
}
