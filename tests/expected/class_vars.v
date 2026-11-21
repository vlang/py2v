module main

import strconv

// Config holds application settings.
pub struct Config {
pub mut:
	debug       bool   = false
	max_retries int    = 3
	name        string = 'default'
	ratio       f64    = 0.5
}

const proxy_type_direct = 0
const proxy_type_manual = 1

pub struct ProxyType {
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
	c := Config{}
	println(if c.debug { 'True' } else { 'False' })
	println(c.max_retries)
	println(c.name)
	println(py2v_float_text1(c.ratio))
	println(proxy_type_direct)
}
