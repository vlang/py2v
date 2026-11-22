module main

import math

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

fn render_py(items []int, divisor int) !string {
	if divisor == 0 {
		return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('zero divisor')] } } })
	}
	mut result := ''
	for value in items {
		result += (math.modulo_floored[int](value, divisor)).str()
	}
	return result
}

fn py2v_entry1() ! {
	println(render_py([1, 2, -3, 4], 2)!)
	println(render_py([1, 2, -3, 4], -3)!)
	println(-7)
	println(math.modulo_floored[int](15, 8))
	println(1)
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
