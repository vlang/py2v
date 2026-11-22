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
		steps = py2v_integer_add1(steps, 1, 'param_rebound.py:5', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
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

fn main() {
	value := 3
	println(countdown(value))
	println(value)
	println(shout('hi', 3))
	println(py2v_float_text1(clamp(-1.5, 0.0)))
	println(py2v_float_text1(clamp(2.5, 0.0)))
	mut c := py2v_new_counter()
	println(c.add(-4))
	println(c.add(5))
}
