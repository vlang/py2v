module py_pkg_call_defaults_consumer

import pyrt

type Any = pyrt.Value

pub fn local_greet_(name string, prefix string) string {
	return prefix + ' ' + name
}

pub fn local_shift_(value int, offset int) int {
	return value + offset
}

pub fn local_optional_(payload Any) string {
	return if pyrt.is_none(payload) { 'None' } else { 'value' }
}

pub fn local_mark_() string {
	println('local argument')
	return 'marked'
}

pub fn local_checked__py(value string) ! {
	if value != 'allowed' {
		return pyrt.raise('ValueError', 'unexpected')
	}
	println(value)
}

pub fn local_checked_(value string) {
	local_checked__py(value) or { pyrt.fail(err) }
}

pub fn run_local_defaults_py() ! {
	println(local_greet_('Ada', 'Private'))
	println(local_greet_('Bob', 'Private'))
	println(local_shift_(8, -2))
	println(local_optional_(pyrt.none_))
	println(local_greet_(local_mark_(), 'Private'))
	println(local_greet_('Ada', 'Explicit'))
	local_checked__py('allowed')!
	local_checked__py('allowed')!
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		local_checked__py('bad') or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			println('caught')
		} else {
			return py2v_raised_1
		}
	}
}

pub fn run_local_defaults() {
	run_local_defaults_py() or { pyrt.fail(err) }
}
