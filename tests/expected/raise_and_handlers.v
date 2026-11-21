module main

import pyrt

pub struct ConfigError {
}

pub struct MissingKey {
	ConfigError
}

fn check_py(n int) !int {
	if n < 0 {
		return pyrt.raise('ValueError', 'negative: ${n}')
	}
	if n == 13 {
		return IError(pyrt.exception('RuntimeError', [pyrt.box('unlucky'), pyrt.box(n)]))
	}
	return n * 2
}

fn read_py(key string) !string {
	if key == '' {
		return IError(pyrt.exception_of('MissingKey', ['ConfigError', 'Exception'], [pyrt.box('empty key')]))
	}
	if key == 'bad' {
		return IError(pyrt.exception_of('ConfigError', ['Exception'], [pyrt.box('bad key')]))
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
		if e := pyrt.caught(py2v_raised_1, 'ValueError') {
			println('caught ${e}')
			return 0
		} else {
			return py2v_raised_1
		}
	} else {
		pyrt.unreachable()
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
			py2v_err_2 = IError(pyrt.exception_of('ConfigError', ['Exception'], [pyrt.box('stop requested')]))
			break py2v_try_2
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if e := pyrt.caught(py2v_raised_2, 'MissingKey') {
			return 'missing: ' + e.str()
		} else if e := pyrt.caught(py2v_raised_2, 'ConfigError') {
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
		if pyrt.caught(py2v_raised_3, 'RuntimeError') != none {
			println('relaying')
			return py2v_raised_3
		} else {
			return py2v_raised_3
		}
	} else {
		pyrt.unreachable()
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
		if e := pyrt.caught(py2v_raised_4, 'Exception') {
			return 'outer got ' + e.str()
		} else {
			pyrt.fail(py2v_raised_4)
		}
	} else {
		pyrt.unreachable()
	}
}

fn main_func_py() ! {
	println('${safe_py(2)!} ${safe_py(-1)!}')
	println((describe_py('a')!).str() + ' ' + ('|').str() + ' ' + (describe_py('')!).str() + ' ' + ('|').str() + ' ' + (describe_py('bad')!).str() + ' ' + ('|').str() + ' ' + (describe_py('stop')!).str())
	println('${outer(4)} | ${outer(13)} | ${outer(-5)}')
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
