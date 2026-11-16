module main

import pyrt.sqlite3
import pyrt

fn show_py(conn &sqlite3.Connection) ! {
	mut name := pyrt.none_
	mut age := pyrt.none_
	conn.execute('CREATE TABLE people (name TEXT, age INTEGER)')!
	conn.execute("INSERT INTO people VALUES ('ada', 36)")!
	conn.execute("INSERT INTO people VALUES ('bob', 41)")!
	conn.commit()!
	row := conn.execute('SELECT name, age FROM people ORDER BY name')!.fetchone()
	if row != none {
		name = sqlite3.must_row(row).get_item(0)!
		age = sqlite3.must_row(row).get_item(1)!
		println('${pyrt.str(name)} ${pyrt.str(age)}')
	}
	missing := conn.execute('SELECT name FROM people WHERE age > 99')!.fetchone()
	if missing == none {
		println('nobody')
	}
	if row != none && missing == none {
		println('one of two')
	}
	for py2v_row1 in conn.execute('SELECT name, age FROM people ORDER BY age DESC')!.fetchall() {
		name = py2v_row1.get_item(0)!
		age = py2v_row1.get_item(1)!
		println('${pyrt.str(name)} ${pyrt.str(age)}')
	}
	rows := conn.execute('SELECT name, age FROM people ORDER BY name')!.fetchall()
	for py2v_row2 in rows {
		name = py2v_row2.get_item(0)!
		age = py2v_row2.get_item(1)!
		println('${pyrt.str(age)} ${pyrt.str(name)}')
	}
	label := if row != none { 'found' } else { 'none' }
	println(label)
}

fn show(conn &sqlite3.Connection) {
	show_py(conn) or { pyrt.fail(err) }
}

fn main() {
	show((sqlite3.connect(':memory:') or { pyrt.fail(err) }))
}
