module main

import pyrt.sqlite3
import pyrt

fn missing_handler_py(conn &sqlite3.Connection) ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		values := (conn.execute('SELECT 1') or {
			py2v_err_1 = err
			break py2v_try_1
		}).fetchall().map(it.get_item(0) or {
			py2v_err_1 = err
			break py2v_try_1
		})
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'sqlite3.Error') != none {
			// pass
		} else {
			return py2v_raised_1
		}
	}
	println(values.len)
}

fn conditional_handler_py(conn &sqlite3.Connection, flag bool) ! {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		mut values := (conn.execute('SELECT 1') or {
			py2v_err_2 = err
			break py2v_try_2
		}).fetchall().map(it.get_item(0) or {
			py2v_err_2 = err
			break py2v_try_2
		})
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'sqlite3.Error') != none {
			if flag {
				values = []
			}
		} else {
			return py2v_raised_2
		}
	}
	println(values.len)
}

fn handler_read_py(conn &sqlite3.Connection) ! {
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		mut values := (conn.execute('SELECT 1') or {
			py2v_err_3 = err
			break py2v_try_3
		}).fetchall().map(it.get_item(0) or {
			py2v_err_3 = err
			break py2v_try_3
		})
		break
	}
	if py2v_raised_3 := py2v_err_3 {
		if pyrt.caught(py2v_raised_3, 'sqlite3.Error') != none {
			println(values.len)
			values = []
		} else {
			return py2v_raised_3
		}
	}
	println(values.len)
}
