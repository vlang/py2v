module main

import pyrt.sqlite3
import pyrt

fn setup_py(path string) !&sqlite3.Connection {
	conn := sqlite3.connect(path)!
	conn.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT, stars INTEGER)')!
	conn.execute('INSERT INTO notes (title, stars) VALUES (?, ?)', pyrt.box('first'), pyrt.box(3))!
	conn.execute('INSERT INTO notes (title, stars) VALUES (?, ?)', pyrt.box('second'), pyrt.box(5))!
	conn.commit()!
	return conn
}

fn setup(path string) &sqlite3.Connection {
	return setup_py(path) or { pyrt.fail(err) }
}

fn titles_py(conn &sqlite3.Connection, least int) ![]string {
	mut found := []string{}
	rows := conn.execute('SELECT title, stars FROM notes WHERE stars >= ? ORDER BY id', pyrt.box(least))!.fetchall()
	for row in rows {
		found << pyrt.str(row.get_item(0)!)
	}
	return found
}

fn titles(conn &sqlite3.Connection, least int) []string {
	return titles_py(conn, least) or { pyrt.fail(err) }
}

fn count_py(conn &sqlite3.Connection) !int {
	cur := conn.cursor()
	cur.execute('SELECT COUNT(*) FROM notes')!
	row := cur.fetchone()
	return conn.execute('SELECT id FROM notes')!.fetchall().len
}

fn count(conn &sqlite3.Connection) int {
	return count_py(conn) or { pyrt.fail(err) }
}

fn main() {
	db := setup(':memory:')
	println(titles(db, 4))
	println(titles(db, 1))
	println(count(db))
	db.close() or { pyrt.fail(err) }
}
