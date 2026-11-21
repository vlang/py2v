module main

import pyrt.sqlite3
import pyrt

fn total_py(db_conn &sqlite3.Connection, least int) !int {
	row := db_conn.execute('SELECT COUNT(*) FROM t WHERE n >= ?', pyrt.box(least))!.fetchone()
	return pyrt.to_int(sqlite3.must_row(row).get_item(0)!)
}

fn first_py(conn &sqlite3.Connection, least int) !int {
	row := conn.execute('SELECT n FROM t WHERE n >= ? ORDER BY n', pyrt.box(least))!.fetchone()
	if row == none {
		return -1
	}
	return pyrt.to_int(sqlite3.must_row(row).get_item(0)!)
}

fn store_py(conn &sqlite3.Connection, n int) ! {
	conn.execute('INSERT INTO t (n) VALUES (?)', pyrt.box(n))!
	conn.commit()!
}

fn main_func_py() ! {
	conn := sqlite3.connect(':memory:')!
	conn.execute('CREATE TABLE t (n INTEGER)')!
	for n in [1, 5, 9] {
		store_py(conn, n)!
	}
	println(total_py(conn, 4)!)
	println('${first_py(conn, 4)!} ${first_py(conn, 50)!}')
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
