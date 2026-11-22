module main

import math.bits as py2v_math_bits1

type Py2vErrorArg = bool | i64 | string

fn (arg Py2vErrorArg) str() string {
	return match arg {
		bool {
			if arg { 'True' } else { 'False' }
		}
		i64 { arg.str() }
		string { arg }
	}
}

struct Py2vErrorArgs {
	values []Py2vErrorArg
}

fn (args Py2vErrorArgs) str() string {
	mut parts := []string{cap: args.values.len}
	for value in args.values {
		if value is string {
			quote := if value.contains('\x27') && !value.contains('\x22') { '\x22' } else { '\x27' }
			escaped := value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t').replace(quote, '\\' + quote)
			parts << quote + escaped + quote
		} else {
			parts << value.str()
		}
	}
	suffix := if parts.len == 1 { ',)' } else { ')' }
	return '(' + parts.join(', ') + suffix
}

struct Py2vErrorData {
	args     Py2vErrorArgs
	original ?IError
	cause    ?IError
}

fn (data Py2vErrorData) str() string {
	if data.args.values.len > 1 {
		return data.args.str()
	}
	value := data.args.values[0] or { return '' }
	return value.str()
}

struct Py2vErrorValueError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorValueError) msg() string {
	return err.data.str()
}

fn py2v_bind_exception1(err IError) Py2vErrorData {
	return match err {
		Py2vErrorValueError { Py2vErrorData{ ...err.data, original: IError(err) } }
		else { panic(err) }
	}
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorValueError { 'ValueError' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

@[inline]
fn py2v_integer_word_product1(a u64, b u64, modulus u64) u64 {
	hi, lo := py2v_math_bits1.mul_64(a, b)
	return py2v_math_bits1.rem_64(hi, lo, modulus)
}

fn py2v_modular_pow1(base int, exponent int, modulus int) !int {
	if modulus == 0 {
		return error('pow() 3rd argument cannot be 0')
	}
	if modulus == 1 || modulus == -1 {
		return 0
	}
	m := if modulus < 0 { u64(-(modulus + 1)) + 1 } else { u64(modulus) }
	remainder := base % modulus
	mut x := if remainder < 0 { m - u64(-remainder) } else { u64(remainder) }
	if exponent < 0 {
		// Euclid's coefficients can be kept reduced modulo m throughout.
		mut old_r, mut r := m, x
		mut old_coefficient, mut coefficient := u64(0), u64(1)
		for r != 0 {
			product := py2v_integer_word_product1(old_r / r, coefficient, m)
			old_r, r = r, old_r % r
			old_coefficient, coefficient = coefficient, if old_coefficient >= product {
				old_coefficient - product
			} else {
				m - (product - old_coefficient)
			}
		}
		if old_r != 1 {
			return error('base is not invertible for the given modulus')
		}
		x = old_coefficient
	}
	mut degree := if exponent < 0 { u64(-(exponent + 1)) + 1 } else { u64(exponent) }
	mut result := u64(1)
	for degree != 0 {
		if degree & 1 != 0 {
			result = py2v_integer_word_product1(result, x, m)
		}
		degree >>= 1
		if degree != 0 {
			x = py2v_integer_word_product1(x, x, m)
		}
	}
	return if modulus < 0 && result != 0 { -int(m - result) } else { int(result) }
}

fn py2v_entry1() ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println((py2v_modular_pow1(int(2), int(-1), int(4)) or {
			py2v_err_1 = IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } })
			break py2v_try_1
		}))
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorValueError {
			problem := py2v_bind_exception1(py2v_raised_1)
			println(problem.str())
		} else {
			return py2v_raised_1
		}
	}
	println((py2v_modular_pow1(int(3), int(4), int(7)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
	println((py2v_modular_pow1(int(5), int(3), int(13)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
