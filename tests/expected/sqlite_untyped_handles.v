module main

import pyrt.sqlite3
import pyrt

type Any = pyrt.Value

fn count_rows_py(conn &sqlite3.Connection, table string) !Any {
	return (conn.execute('SELECT COUNT(*) FROM ' + table)!.fetchone() or { panic("TypeError: 'NoneType' object is not subscriptable") }).get_item(0)!
}

fn add_py(conn &sqlite3.Connection, title string) ! {
	conn.execute('INSERT INTO notes (title) VALUES (?)', pyrt.box(title))!
	conn.commit()!
}

fn titles_py(cur &sqlite3.Cursor) ![]Any {
	cur.execute('SELECT title FROM notes ORDER BY id')!
	return cur.fetchall().map(it.get_item(0)!)
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

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
