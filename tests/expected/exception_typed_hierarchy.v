module main

pub struct EntryError {
}

pub struct MissingEntry {
	EntryError
}

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

struct Py2vErrorLookupError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorLookupError) msg() string {
	return err.data.str()
}

struct Py2vErrorMissingEntry {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorMissingEntry) msg() string {
	return err.data.str()
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
		Py2vErrorLookupError { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorMissingEntry { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorValueError { Py2vErrorData{ ...err.data, original: IError(err) } }
		else { panic(err) }
	}
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorLookupError { 'LookupError' }
		Py2vErrorMissingEntry { 'MissingEntry' }
		Py2vErrorValueError { 'ValueError' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

fn lookup_py() ! {
	return IError(Py2vErrorMissingEntry{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('missing entry')] } } })
}

fn read_py() ! {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		mut py2v_err_1 := ?IError(none)
		py2v_try_1: for {
			lookup_py() or {
				py2v_err_1 = err
				break py2v_try_1
			}
			break
		}
		if py2v_raised_1 := py2v_err_1 {
			if py2v_raised_1 is Py2vErrorValueError {
				println('unexpected')
			} else {
				py2v_err_2 = py2v_raised_1
				break py2v_try_2
			}
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if py2v_raised_2 is Py2vErrorLookupError || py2v_raised_2 is Py2vErrorMissingEntry {
			problem := py2v_bind_exception1(py2v_raised_2)
			println(problem)
			println(problem.args)
		} else {
			return py2v_raised_2
		}
	}
}

fn py2v_entry1() ! {
	read_py()!
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
