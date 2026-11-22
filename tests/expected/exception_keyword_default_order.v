module main

const default_offset = 7

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

fn combine_py(first int, second int, offset int) !int {
	if first < 0 {
		return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('negative first argument')] } } })
	}
	return int(int(py2v_integer_mul1(first, 100, 'exception_keyword_default_order.py:7', 'multiplication')) + int(py2v_integer_mul1(second, 10, 'exception_keyword_default_order.py:7', 'multiplication'))) + offset
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_entry1() ! {
	println(combine_py(1, 2, default_offset)!)
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println(combine_py(-1, 2, default_offset) or {
			py2v_err_1 = err
			break py2v_try_1
		})
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorValueError {
			exc := py2v_bind_exception1(py2v_raised_1)
			println(exc)
		} else {
			return py2v_raised_1
		}
	}
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
