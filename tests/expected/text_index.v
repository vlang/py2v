module main

import pyrt

fn char_at_py(text string, index int) !string {
	return py2v_string_index1(text, index, pyrt.raise('IndexError', 'string index out of range'))!
}

fn is_drop_py(text string) !bool {
	return '@' == py2v_string_index1(text, 1, pyrt.raise('IndexError', 'string index out of range'))!
}

fn py2v_string_index1(value string, index i64, index_error ?IError) !string {
	chars := value.runes()
	offset := if index < 0 { i64(chars.len) + index } else { index }
	if offset < 0 || offset >= i64(chars.len) {
		return index_error or { error('IndexError: string index out of range') }
	}
	return chars[int(offset)].str()
}

fn py2v_entry1() ! {
	println(char_at_py('é♞n', 1)!)
	println(char_at_py('é♞n', -3)!)
	println(if is_drop_py('P@e4')! { 'True' } else { 'False' })
	println(py2v_string_index1('v4', 1, pyrt.raise('IndexError', 'string index out of range'))!.int())
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println(char_at_py('fa', 12) or {
			py2v_err_1 = err
			break py2v_try_1
		})
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'IndexError') != none {
			println('out of range')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
