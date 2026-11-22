module main

import strconv

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

struct Py2vErrorArithmeticError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorArithmeticError) msg() string {
	return err.data.str()
}

struct Py2vErrorIndexError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorIndexError) msg() string {
	return err.data.str()
}

struct Py2vErrorZeroDivisionError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorZeroDivisionError) msg() string {
	return err.data.str()
}

fn py2v_bind_exception1(err IError) Py2vErrorData {
	return match err {
		Py2vErrorArithmeticError { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorIndexError { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorZeroDivisionError { Py2vErrorData{ ...err.data, original: IError(err) } }
		else { panic(err) }
	}
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorArithmeticError { 'ArithmeticError' }
		Py2vErrorIndexError { 'IndexError' }
		Py2vErrorZeroDivisionError { 'ZeroDivisionError' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

fn evaluate_py(divisor int, index int) ! {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		println(py2v_float_text1(py2v_checked_true_div1(f64(8), f64(divisor), 'division by zero') or {
			py2v_err_2 = err
			break py2v_try_2
		}))
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if py2v_raised_2 is Py2vErrorArithmeticError || py2v_raised_2 is Py2vErrorZeroDivisionError {
			problem := py2v_bind_exception1(py2v_raised_2)
			println(problem)
		} else {
			return py2v_raised_2
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println(py2v_checked_list_index1([1, 2], index) or {
			py2v_err_1 = err
			break py2v_try_1
		})
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorIndexError {
			problem := py2v_bind_exception1(py2v_raised_1)
			println(problem)
		} else {
			return py2v_raised_1
		}
	}
}

fn py2v_checked_true_div1(a f64, b f64, message string) !f64 {
	if b == 0 {
		return IError(Py2vErrorZeroDivisionError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(message)] } } })
	}
	return a / b
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

fn py2v_checked_list_index1[T](items []T, index int) !T {
	position := if index < 0 { items.len + index } else { index }
	if position < 0 || position >= items.len {
		return IError(Py2vErrorIndexError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('list index out of range')] } } })
	}
	return items[position]
}

fn py2v_entry1() ! {
	evaluate_py(0, 2)!
	evaluate_py(4, -1)!
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
