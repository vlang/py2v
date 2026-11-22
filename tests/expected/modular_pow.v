module main

import math.big as py2v_big

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

fn residue_py(base int, exponent int, modulus int) !int {
	return py2v_modular_pow1(int(base), int(exponent), int(modulus)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }
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

fn py2v_entry1() ! {
	values := [7, -4, i64(123456789123456789), i64(9223372036854775783)]
	println(residue_py(values[0], values[1], 13)!)
	println(residue_py(values[2], 547, values[3])!)
	println(residue_py(-2, 3, -5)!)
	println((py2v_modular_pow1(int(1), int(i64(-9223372036854775808)), int(-7)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
	println(residue_py(0, -1, 1)!)
	println((py2v_modular_pow1(int(true), int(false), int(4)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		residue_py(2, 5, 0) or {
			py2v_err_2 = err
			break py2v_try_2
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if py2v_raised_2 is Py2vErrorValueError {
			exc := py2v_bind_exception1(py2v_raised_2)
			println(exc.str())
		} else {
			return py2v_raised_2
		}
	}
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
			exc := py2v_bind_exception1(py2v_raised_1)
			println(exc.str())
		} else {
			return py2v_raised_1
		}
	}
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
