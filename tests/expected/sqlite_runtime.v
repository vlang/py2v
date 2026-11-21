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

fn titles_py(conn &sqlite3.Connection, least int) ![]string {
	mut found := []string{}
	rows := conn.execute('SELECT title, stars FROM notes WHERE stars >= ? ORDER BY id', pyrt.box(least))!.fetchall()
	for row in rows {
		found << pyrt.str(row.get_item(0)!)
	}
	return found
}

fn count_py(conn &sqlite3.Connection) !int {
	cur := conn.cursor()
	cur.execute('SELECT COUNT(*) FROM notes')!
	row := cur.fetchone()
	return conn.execute('SELECT id FROM notes')!.fetchall().len
}

fn py2v_entry1() ! {
	db := setup_py(':memory:')!
	println(titles_py(db, 4)!)
	println(titles_py(db, 1)!)
	println(count_py(db)!)
	db.close()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
