module main

pub struct Reader {
}

fn (self Reader) read_number_py(number int) !int {
	if number < 0 {
		return IError(Py2vErrorIndexError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('negative number')] } } })
	}
	return number
}

fn (self Reader) read_number(number int) int {
	return self.read_number_py(number) or { py2v_uncaught_exception1(err) }
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

struct Py2vErrorIndexError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorIndexError) msg() string {
	return err.data.str()
}

struct Py2vErrorLookupError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorLookupError) msg() string {
	return err.data.str()
}

fn py2v_bind_exception1(err IError) Py2vErrorData {
	return match err {
		Py2vErrorIndexError { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorLookupError { Py2vErrorData{ ...err.data, original: IError(err) } }
		else { panic(err) }
	}
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorIndexError { 'IndexError' }
		Py2vErrorLookupError { 'LookupError' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

fn collect_py() ! {
	reader := Reader{}
	println([3, -1, 5].map(reader.read_number_py(it)!))
}

fn py2v_entry1() ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		collect_py() or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorIndexError || py2v_raised_1 is Py2vErrorLookupError {
			problem := py2v_bind_exception1(py2v_raised_1)
			println(problem)
		} else {
			return py2v_raised_1
		}
	}
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
