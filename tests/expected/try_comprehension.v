module main

import pyrt.sqlite3
import pyrt

type Any = pyrt.Value

fn collect_py(conn &sqlite3.Connection, query string) ! {
	mut values := []Any{}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		values = (conn.execute(query) or {
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
			values = []
		} else {
			return py2v_raised_1
		}
	}
	println(values.len)
}

fn handlers_py(conn &sqlite3.Connection, kind int) ! {
	mut values := []Any{}
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		if kind == 1 {
			py2v_err_2 = pyrt.raise('ValueError', 'fallback')
			break py2v_try_2
		}
		if kind == 2 {
			py2v_err_2 = pyrt.raise('TypeError', 'fallback')
			break py2v_try_2
		}
		values = (conn.execute('SELECT 2') or {
			py2v_err_2 = err
			break py2v_try_2
		}).fetchall().map(it.get_item(0) or {
			py2v_err_2 = err
			break py2v_try_2
		})
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'ValueError') != none {
			values = [7]
		} else if pyrt.caught(py2v_raised_2, 'TypeError') != none {
			values = [8]
		} else {
			return py2v_raised_2
		}
	}
	println('${values.len} ${pyrt.str(values[0])}')
}

fn returning_py(conn &sqlite3.Connection, query string) ! {
	mut values := []Any{}
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		values = (conn.execute(query) or {
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
			println('returned')
			return
		} else {
			return py2v_raised_3
		}
	}
	println(values.len)
}

fn reraising_py(conn &sqlite3.Connection, query string) ! {
	mut values := []Any{}
	mut py2v_err_4 := ?IError(none)
	py2v_try_4: for {
		values = (conn.execute(query) or {
			py2v_err_4 = err
			break py2v_try_4
		}).fetchall().map(it.get_item(0) or {
			py2v_err_4 = err
			break py2v_try_4
		})
		break
	}
	if py2v_raised_4 := py2v_err_4 {
		if pyrt.caught(py2v_raised_4, 'sqlite3.Error') != none {
			return py2v_raised_4
		} else {
			return py2v_raised_4
		}
	}
	println(values.len)
}

fn dynamic_collect_py(items []Any) ! {
	mut values := []Any{}
	mut py2v_err_5 := ?IError(none)
	py2v_try_5: for {
		values = items.map(pyrt.call_method(pyrt.box(it), 'get', [pyrt.box('x')]) or {
			py2v_err_5 = err
			break py2v_try_5
		})
		break
	}
	if py2v_raised_5 := py2v_err_5 {
		if pyrt.caught(py2v_raised_5, 'AttributeError') != none {
			values = []
		} else {
			return py2v_raised_5
		}
	}
	println(values.len)
	if values.len > 0 {
		println(pyrt.str(values[0]))
	}
}

fn py2v_entry1() ! {
	conn := sqlite3.connect(':memory:')!
	collect_py(conn, 'SELECT 1')!
	collect_py(conn, 'SELECT missing')!
	handlers_py(conn, 0)!
	handlers_py(conn, 1)!
	handlers_py(conn, 2)!
	returning_py(conn, 'SELECT 1')!
	returning_py(conn, 'SELECT missing')!
	reraising_py(conn, 'SELECT 1')!
	mut py2v_err_6 := ?IError(none)
	py2v_try_6: for {
		reraising_py(conn, 'SELECT missing') or {
			py2v_err_6 = err
			break py2v_try_6
		}
		break
	}
	if py2v_raised_6 := py2v_err_6 {
		if pyrt.caught(py2v_raised_6, 'sqlite3.Error') != none {
			println('reraised')
		} else {
			pyrt.fail(py2v_raised_6)
		}
	}
	dynamic_collect_py([pyrt.box(map[string]Any{
		'x': pyrt.box(3)
	})].map(Any(it)))!
	dynamic_collect_py([1].map(Any(it)))!
	conn.close()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
