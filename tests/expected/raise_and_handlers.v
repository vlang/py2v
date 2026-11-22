module main

pub struct ConfigError {
}

pub struct MissingKey {
	ConfigError
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

struct Py2vErrorConfigError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorConfigError) msg() string {
	return err.data.str()
}

struct Py2vErrorException {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorException) msg() string {
	return err.data.str()
}

struct Py2vErrorMissingKey {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorMissingKey) msg() string {
	return err.data.str()
}

struct Py2vErrorRuntimeError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorRuntimeError) msg() string {
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
		Py2vErrorConfigError { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorException { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorMissingKey { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorRuntimeError { Py2vErrorData{ ...err.data, original: IError(err) } }
		Py2vErrorValueError { Py2vErrorData{ ...err.data, original: IError(err) } }
		else { panic(err) }
	}
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorConfigError { 'ConfigError' }
		Py2vErrorException { 'Exception' }
		Py2vErrorMissingKey { 'MissingKey' }
		Py2vErrorRuntimeError { 'RuntimeError' }
		Py2vErrorValueError { 'ValueError' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

fn check_py(n int) !int {
	if n < 0 {
		return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('negative: ${n}')] } } })
	}
	if n == 13 {
		return IError(Py2vErrorRuntimeError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [
			Py2vErrorArg('unlucky'),
			Py2vErrorArg(i64(n)),
		] } } })
	}
	return py2v_integer_mul1(n, 2, 'raise_and_handlers.py:14', 'multiplication')
}

fn read_py(key string) !string {
	if key == '' {
		return IError(Py2vErrorMissingKey{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('empty key')] } } })
	}
	if key == 'bad' {
		return IError(Py2vErrorConfigError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('bad key')] } } })
	}
	return key.to_upper()
}

fn safe_py(n int) !int {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		return check_py(n) or {
			py2v_err_1 = err
			break py2v_try_1
		}
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorValueError {
			e := py2v_bind_exception1(py2v_raised_1)
			println('caught ${e}')
			return 0
		} else {
			return py2v_raised_1
		}
	} else {
		panic('unreachable try completion')
	}
}

fn describe_py(key string) !string {
	mut value := ''
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		value = read_py(key) or {
			py2v_err_2 = err
			break py2v_try_2
		}
		if value == 'STOP' {
			py2v_err_2 = IError(Py2vErrorConfigError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('stop requested')] } } })
			break py2v_try_2
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if py2v_raised_2 is Py2vErrorMissingKey {
			e := py2v_bind_exception1(py2v_raised_2)
			return 'missing: ' + e.str()
		} else if py2v_raised_2 is Py2vErrorConfigError || py2v_raised_2 is Py2vErrorMissingKey {
			e := py2v_bind_exception1(py2v_raised_2)
			return 'config: ' + e.str()
		} else {
			return py2v_raised_2
		}
	}
	return 'ok ' + value
}

fn relay_py(n int) !int {
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		return check_py(n) or {
			py2v_err_3 = err
			break py2v_try_3
		}
	}
	if py2v_raised_3 := py2v_err_3 {
		if py2v_raised_3 is Py2vErrorRuntimeError {
			println('relaying')
			return py2v_raised_3
		} else {
			return py2v_raised_3
		}
	} else {
		panic('unreachable try completion')
	}
}

fn outer(n int) string {
	mut py2v_err_4 := ?IError(none)
	py2v_try_4: for {
		return (relay_py(n) or {
			py2v_err_4 = err
			break py2v_try_4
		}).str()
	}
	if py2v_raised_4 := py2v_err_4 {
		if py2v_raised_4 is Py2vErrorConfigError || py2v_raised_4 is Py2vErrorException || py2v_raised_4 is Py2vErrorMissingKey || py2v_raised_4 is Py2vErrorRuntimeError || py2v_raised_4 is Py2vErrorValueError {
			e := py2v_bind_exception1(py2v_raised_4)
			return 'outer got ' + e.str()
		} else {
			py2v_uncaught_exception1(py2v_raised_4)
		}
	} else {
		panic('unreachable try completion')
	}
}

fn main_func_py() ! {
	println('${safe_py(2)!} ${safe_py(-1)!}')
	println((describe_py('a')!).str() + ' ' + ('|').str() + ' ' + (describe_py('')!).str() + ' ' + ('|').str() + ' ' + (describe_py('bad')!).str() + ' ' + ('|').str() + ' ' + (describe_py('stop')!).str())
	println('${outer(4)} | ${outer(13)} | ${outer(-5)}')
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
	main_func_py()!
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
