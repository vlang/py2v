module main

pub struct Counter {
}

fn (self Counter) walk_py(n int) !int {
	if n == 0 {
		return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('bottom')] } } })
	}
	return self.walk_py(n - 1)!
}

fn (self Counter) walk(n int) int {
	return self.walk_py(n) or { py2v_uncaught_exception1(err) }
}

fn (self Counter) go_py(n int) !int {
	if n == 0 {
		return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('go-bottom')] } } })
	}
	return self.go_py(n - 1)!
}

fn (self Counter) go(n int) int {
	return self.go_py(n) or { py2v_uncaught_exception1(err) }
}

fn (self Counter) leaf_py(n int) !int {
	if n == 0 {
		return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('leaf')] } } })
	}
	return n
}

fn (self Counter) leaf(n int) int {
	return self.leaf_py(n) or { py2v_uncaught_exception1(err) }
}

fn (self Counter) through_py(n int) !int {
	return self.leaf_py(n)!
}

fn (self Counter) through(n int) int {
	return self.through_py(n) or { py2v_uncaught_exception1(err) }
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

fn py2v_entry1() ! {
	counter := Counter{}
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		counter.walk_py(2) or {
			py2v_err_3 = err
			break py2v_try_3
		}
		break
	}
	if py2v_raised_3 := py2v_err_3 {
		if py2v_raised_3 is Py2vErrorValueError {
			problem := py2v_bind_exception1(py2v_raised_3)
			println('recursive ${problem.str()}')
		} else {
			return py2v_raised_3
		}
	}
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		println(counter.go_py(2) or {
			py2v_err_2 = err
			break py2v_try_2
		})
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if py2v_raised_2 is Py2vErrorValueError {
			problem := py2v_bind_exception1(py2v_raised_2)
			println('reserved ${problem.str()}')
		} else {
			return py2v_raised_2
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		counter.through_py(0) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorValueError {
			problem := py2v_bind_exception1(py2v_raised_1)
			println('through ${problem.str()}')
		} else {
			return py2v_raised_1
		}
	}
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
