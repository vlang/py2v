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

struct Py2vErrorValueError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorValueError) msg() string {
	return err.data.str()
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

fn from_try_py(flag bool) !int {
	mut result := 0
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		if !flag {
			py2v_err_1 = IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('x')] } } })
			break py2v_try_1
		}
		result = 10
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorValueError {
			result = 20
		} else {
			return py2v_raised_1
		}
	}
	return result
}

fn py2v_entry1() ! {
	println(from_try_py(true)!)
	println(from_try_py(false)!)
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
