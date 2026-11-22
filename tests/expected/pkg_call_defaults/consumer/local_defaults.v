module py_pkg_call_defaults_consumer

import pyrt

type Any = pyrt.Value

pub fn local_greet_(name string, prefix string) string {
	return prefix + ' ' + name
}

pub fn local_shift_(value int, offset int) int {
	return py2v_integer_add1(value, offset, 'consumer/local_defaults.py:9', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}
