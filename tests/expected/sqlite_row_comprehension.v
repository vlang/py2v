module main

import pyrt.sqlite3
import pyrt

fn show_py(conn &sqlite3.Connection) ! {
	conn.execute('CREATE TABLE t (n INTEGER, name TEXT)')!
	conn.execute("INSERT INTO t VALUES (1, 'a'), (2, 'b')")!
	rows := conn.execute('SELECT n, name FROM t ORDER BY n')!.fetchall()
	ids := rows.map(it.get_item(0)!)
	names := rows.map({
		'id':   it.get_item(0)!
		'name': it.get_item(1)!
	})
	println('${pyrt.str(pyrt.box(ids))} ${names.len}')
	firsts := conn.execute('SELECT n, name FROM t WHERE n > 1')!.fetchall().filter(pyrt.truth(it.get_item(0)!)).map(it.get_item(1)!)
	println(pyrt.str(pyrt.box(firsts)))
}

fn show(conn &sqlite3.Connection) {
	show_py(conn) or { pyrt.fail(err) }
}

fn main() {
	show((sqlite3.connect(':memory:') or { pyrt.fail(err) }))
}
