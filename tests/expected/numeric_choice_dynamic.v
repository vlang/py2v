module main

import pyrt
import strconv

type Any = pyrt.Value

fn score(x int) Py2vNumber {
	return if x == 0 { Py2vNumber(int(0)) } else { Py2vNumber(f64(2.5 / f64(x))) }
}

fn show(x Any) {
	println(pyrt.str(x))
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

type Py2vNumber = f64 | int

fn (value Py2vNumber) str() string {
	return match value {
		f64 { py2v_float_text1(value) }
		int { value.str() }
	}
}

fn py2v_numeric_type_name1(value Py2vNumber) string {
	return match value {
		f64 { 'float' }
		int { 'int' }
	}
}

fn py2v_numeric_box1(value Py2vNumber) pyrt.Value {
	return match value {
		f64 { pyrt.box(value) }
		int { pyrt.box(value) }
	}
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
}

fn main() {
	println('${score(0).str()} ${score(2).str()}')
	println((if (py2v_numeric_type_name1(score(0)) in ['int', 'bool']) { 'True' } else { 'False' }).str() + ' ' + (if (py2v_numeric_type_name1(score(2)) in ['float']) {
		'True'
	} else {
		'False'
	}).str())
	show(py2v_numeric_box1(if 0 == 0 { Py2vNumber(int(0)) } else { Py2vNumber(f64(f64(9) / 2)) }))
	show(py2v_numeric_box1(if 1 == 0 { Py2vNumber(int(0)) } else { Py2vNumber(f64(f64(9) / 2)) }))
	values := [0, 2].map(if it == 0 {
		Py2vNumber(int(0))
	} else {
		Py2vNumber(f64(py2v_true_div1(8, it)))
	})
	println(values)
	println((if values[0] is int { 'True' } else { 'False' }).str() + ' ' + (if values[1] is f64 {
		'True'
	} else {
		'False'
	}).str())
	println('${if 0 == 0 { Py2vNumber(int(0)) } else { Py2vNumber(f64(f64(7) / 2)) }}')
	println('${if 1 == 0 { Py2vNumber(int(0)) } else { Py2vNumber(f64(f64(7) / 2)) }}')
}
