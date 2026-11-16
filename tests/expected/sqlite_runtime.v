module main

import pyrt.sqlite3
import pyrt

fn setup(path string) &sqlite3.Connection {
	conn := (sqlite3.connect(path) or { pyrt.fail(err) })
	conn.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT, stars INTEGER)') or { pyrt.fail(err) }
	conn.execute('INSERT INTO notes (title, stars) VALUES (?, ?)', pyrt.box('first'), pyrt.box(3)) or { pyrt.fail(err) }
	conn.execute('INSERT INTO notes (title, stars) VALUES (?, ?)', pyrt.box('second'), pyrt.box(5)) or { pyrt.fail(err) }
	conn.commit() or { pyrt.fail(err) }
	return conn
}

fn titles(conn &sqlite3.Connection, least int) []string {
	mut found := []string{}
	rows := (conn.execute('SELECT title, stars FROM notes WHERE stars >= ? ORDER BY id', pyrt.box(least)) or { pyrt.fail(err) }).fetchall()
	for row in rows {
		found << pyrt.str(row.get_item(0) or { pyrt.fail(err) })
	}
	return found
}

fn count(conn &sqlite3.Connection) int {
	cur := conn.cursor()
	cur.execute('SELECT COUNT(*) FROM notes') or { pyrt.fail(err) }
	row := cur.fetchone()
	return (conn.execute('SELECT id FROM notes') or { pyrt.fail(err) }).fetchall().len
}

fn main() {
	db := setup(':memory:')
	println(titles(db, 4))
	println(titles(db, 1))
	println(count(db))
	db.close() or { pyrt.fail(err) }
}
