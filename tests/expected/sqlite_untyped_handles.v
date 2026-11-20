module main

import pyrt.sqlite3
import pyrt

type Any = pyrt.Value

fn count_rows_py(conn &sqlite3.Connection, table string) !Any {
	return (conn.execute('SELECT COUNT(*) FROM ' + table)!.fetchone() or { panic("TypeError: 'NoneType' object is not subscriptable") }).get_item(0)!
}

fn count_rows(conn &sqlite3.Connection, table string) Any {
	return count_rows_py(conn, table) or { pyrt.fail(err) }
}

fn add_py(conn &sqlite3.Connection, title string) ! {
	conn.execute('INSERT INTO notes (title) VALUES (?)', pyrt.box(title))!
	conn.commit()!
}

fn add(conn &sqlite3.Connection, title string) {
	add_py(conn, title) or { pyrt.fail(err) }
}

fn titles_py(cur &sqlite3.Cursor) ![]Any {
	cur.execute('SELECT title FROM notes ORDER BY id')!
	return cur.fetchall().map(it.get_item(0)!)
}

fn titles(cur &sqlite3.Cursor) []Any {
	return titles_py(cur) or { pyrt.fail(err) }
}

fn main_func_py() ! {
	conn := sqlite3.connect(':memory:')!
	conn.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT)')!
	add_py(conn, 'a')!
	add_py(conn, 'b')!
	println(pyrt.str(count_rows_py(conn, 'notes')!))
	println(pyrt.str(pyrt.box(titles_py(conn.cursor())!)))
	conn.close()!
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
