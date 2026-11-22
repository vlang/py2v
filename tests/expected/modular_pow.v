module main

import math.big as py2v_big
import pyrt

fn residue_py(base int, exponent int, modulus int) !int {
	return py2v_modular_pow1(int(base), int(exponent), int(modulus)) or { return pyrt.raise('ValueError', err.msg()) }
}

fn residue(base int, exponent int, modulus int) int {
	return residue_py(base, exponent, modulus) or { pyrt.fail(err) }
}

fn py2v_modular_pow1(base int, exponent int, modulus int) !int {
	if modulus == 0 {
		return error('pow() 3rd argument cannot be 0')
	}
	if modulus == 1 || modulus == -1 {
		return 0
	}
	m := py2v_big.integer_from_i64(i64(modulus)).abs()
	mut x := py2v_big.integer_from_i64(i64(base))
	if exponent < 0 {
		x = x.mod_inverse(m) or { return error('base is not invertible for the given modulus') }
	}
	degree := if exponent < 0 { u64(-(exponent + 1)) + 1 } else { u64(exponent) }
	result := x.mod_pow(degree, m)
	if modulus < 0 && result != py2v_big.integer_from_u64(0) {
		return int((result - m).str().i64())
	}
	return int(result.str().i64())
}

fn main() {
	values := [7, -4, i64(123456789123456789), i64(9223372036854775783)]
	println(residue(values[0], values[1], 13))
	println(residue(values[2], 547, values[3]))
	println(residue(-2, 3, -5))
	println((py2v_modular_pow1(int(1), int(i64(-9223372036854775808)), int(-7)) or { panic('ValueError: ' + err.msg()) }))
	println(residue(0, -1, 1))
	println((py2v_modular_pow1(int(true), int(false), int(4)) or { panic('ValueError: ' + err.msg()) }))
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		residue_py(2, 5, 0) or {
			py2v_err_2 = err
			break py2v_try_2
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if exc := pyrt.caught(py2v_raised_2, 'ValueError') {
			println(exc.str())
		} else {
			pyrt.fail(py2v_raised_2)
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println((py2v_modular_pow1(int(2), int(-1), int(4)) or {
			py2v_err_1 = pyrt.raise('ValueError', err.msg())
			break py2v_try_1
		}))
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if exc := pyrt.caught(py2v_raised_1, 'ValueError') {
			println(exc.str())
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}
