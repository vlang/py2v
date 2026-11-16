module main

import pyrt.sqlite3
import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn count_rows(conn &sqlite3.Connection, table string) Any {
	return ((conn.execute('SELECT COUNT(*) FROM ' + table) or { pyrt.fail(err) }).fetchone() or { panic("TypeError: 'NoneType' object is not subscriptable") }).get_item(0) or { pyrt.fail(err) }
}

fn add(conn &sqlite3.Connection, title string) {
	conn.execute('INSERT INTO notes (title) VALUES (?)', pyrt.box(title)) or { pyrt.fail(err) }
	conn.commit() or { pyrt.fail(err) }
}

fn titles(cur &sqlite3.Cursor) []Any {
	cur.execute('SELECT title FROM notes ORDER BY id') or { pyrt.fail(err) }
	return cur.fetchall().map(it.get_item(0) or { pyrt.fail(err) })
}

fn main_func() {
	conn := (sqlite3.connect(':memory:') or { pyrt.fail(err) })
	conn.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT)') or { pyrt.fail(err) }
	add(conn, 'a')
	add(conn, 'b')
	println(pyrt.str(count_rows(conn, 'notes')))
	println(pyrt.str(pyrt.box(titles(conn.cursor()))))
	conn.close() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
