module main

import pyrt.json
import pyrt
import pyrt.sqlite3

fn parse_py(text string) !int {
	mut count := 0
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		data := json.loads(text) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		count = pyrt.length(data)
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if e := pyrt.caught(py2v_raised_1, 'JSONDecodeError') {
			println('bad json: ${e.str()[..12]}')
			return -1
		} else {
			return py2v_raised_1
		}
	} else {
		println('parsed')
	}
	return count
}

fn parse(text string) int {
	return parse_py(text) or { pyrt.fail(err) }
}

fn lookup(conn &sqlite3.Connection, table string) int {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		row := (conn.execute('SELECT COUNT(*) FROM ' + table) or {
			py2v_err_2 = err
			break py2v_try_2
		}).fetchone()
		return pyrt.to_int(sqlite3.must_row(row).get_item(0) or {
			py2v_err_2 = err
			break py2v_try_2
		})
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'sqlite3.OperationalError') != none {
			return -1
		} else if e := pyrt.caught(py2v_raised_2, 'Exception') {
			println('other ${e}')
			return -2
		} else {
			pyrt.fail(py2v_raised_2)
		}
	} else {
		pyrt.unreachable()
	}
}

fn insert_py(conn &sqlite3.Connection, n int) !string {
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		conn.execute('INSERT INTO t (n) VALUES (?)', pyrt.box(n)) or {
			py2v_err_3 = err
			break py2v_try_3
		}
		conn.commit() or {
			py2v_err_3 = err
			break py2v_try_3
		}
		break
	}
	if py2v_raised_3 := py2v_err_3 {
		if e := pyrt.caught(py2v_raised_3, 'sqlite3.IntegrityError') {
			return 'duplicate: ' + e.str()
		} else {
			return py2v_raised_3
		}
	}
	return 'stored'
}

fn insert(conn &sqlite3.Connection, n int) string {
	return insert_py(conn, n) or { pyrt.fail(err) }
}

fn main_func_py() ! {
	println(parse_py('{\"a\": 1, \"b\": 2}')!)
	println(parse_py('{not json')!)
	conn := sqlite3.connect(':memory:')!
	conn.execute('CREATE TABLE t (n INTEGER PRIMARY KEY)')!
	println(insert_py(conn, 1)!)
	println(insert_py(conn, 1)!)
	println(lookup(conn, 't'))
	println(lookup(conn, 'missing'))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
