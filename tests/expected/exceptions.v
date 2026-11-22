module main

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

struct Py2vErrorException {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorException) msg() string {
	return err.data.str()
}

fn py2v_bind_exception1(err IError) Py2vErrorData {
	return match err {
		Py2vErrorException { Py2vErrorData{ ...err.data, original: IError(err) } }
		else { panic(err) }
	}
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorException { 'Exception' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

fn show() {
	{
		defer {
			println('Finally')
		}
		mut py2v_err_3 := ?IError(none)
		py2v_try_3: for {
			py2v_err_3 = IError(Py2vErrorException{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('foo')] } } })
			break py2v_try_3
		}
		if py2v_raised_3 := py2v_err_3 {
			if py2v_raised_3 is Py2vErrorException {
				e := py2v_bind_exception1(py2v_raised_3)
				println('caught')
			} else {
				py2v_uncaught_exception1(py2v_raised_3)
			}
		}
	}
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		py2v_err_2 = IError(Py2vErrorException{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('foo')] } } })
		break py2v_try_2
	}
	if py2v_err_2 != none {
		{
			println('Got it')
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		py2v_err_1 = IError(Py2vErrorException{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('foo')] } } })
		break py2v_try_1
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorException {
			e := py2v_bind_exception1(py2v_raised_1)
			assert e.str().contains('foo')
		} else {
			py2v_uncaught_exception1(py2v_raised_1)
		}
	}
}

fn main() {
	show()
}
