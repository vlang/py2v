module main

import pyrt.sqlite3
import pyrt

fn total(db_conn &sqlite3.Connection, least int) int {
	row := (db_conn.execute('SELECT COUNT(*) FROM t WHERE n >= ?', pyrt.box(least)) or { pyrt.fail(err) }).fetchone()
	return pyrt.to_int(sqlite3.must_row(row).get_item(0) or { pyrt.fail(err) })
}

fn first(conn &sqlite3.Connection, least int) int {
	row := (conn.execute('SELECT n FROM t WHERE n >= ? ORDER BY n', pyrt.box(least)) or { pyrt.fail(err) }).fetchone()
	if row == none {
		return -1
	}
	return pyrt.to_int(sqlite3.must_row(row).get_item(0) or { pyrt.fail(err) })
}

fn store(conn &sqlite3.Connection, n int) {
	conn.execute('INSERT INTO t (n) VALUES (?)', pyrt.box(n)) or { pyrt.fail(err) }
	conn.commit() or { pyrt.fail(err) }
}

fn main_func() {
	conn := (sqlite3.connect(':memory:') or { pyrt.fail(err) })
	conn.execute('CREATE TABLE t (n INTEGER)') or { pyrt.fail(err) }
	for n in [1, 5, 9] {
		store(conn, n)
	}
	println(total(conn, 4))
	println('${first(conn, 4)} ${first(conn, 50)}')
}

fn main() {
	main_func()
}
