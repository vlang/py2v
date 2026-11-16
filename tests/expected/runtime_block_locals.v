module main

import os
import pyrt.sqlite3
import pyrt.subprocess
import pyrt.pathlib
import pyrt

fn show_py(conn &sqlite3.Connection, flag bool) ! {
	mut rows := []sqlite3.Row{}
	mut row := ?sqlite3.Row(none)
	mut result := subprocess.CompletedProcess{}
	mut where := pathlib.Path{}
	if flag {
		rows = conn.execute('SELECT 1, 2')!.fetchall()
		row = conn.execute('SELECT 3')!.fetchone()
		result = subprocess.run(['true'], capture_output: true, text: true)!
		where = pathlib.new_path('/tmp')
	} else {
		rows = conn.execute('SELECT 1 WHERE 0')!.fetchall()
		row = conn.execute('SELECT 1 WHERE 0')!.fetchone()
		result = subprocess.run(['false'], capture_output: true, text: true)!
		where = pathlib.new_path('here')
	}
	println((rows.len).str() + ' ' + (if row == none { 'True' } else { 'False' }).str() + ' ' + (result.returncode).str() + ' ' + (where.name()).str())
}

fn show(conn &sqlite3.Connection, flag bool) {
	show_py(conn, flag) or { pyrt.fail(err) }
}

fn count_py(path string, fresh bool) !int {
	mut conn := &sqlite3.Connection(unsafe { nil })
	mut cur := &sqlite3.Cursor(unsafe { nil })
	if fresh {
		conn = sqlite3.connect(':memory:')!
		cur = conn.cursor()
	} else {
		conn = sqlite3.connect(path)!
		cur = conn.cursor()
	}
	cur.execute('SELECT 41 + 1')!
	return cur.fetchall().len
}

fn count(path string, fresh bool) int {
	return count_py(path, fresh) or { pyrt.fail(err) }
}

fn main() {
	db := (sqlite3.connect(':memory:') or { pyrt.fail(err) })
	show(db, true)
	show(db, false)
	stamp := pathlib.new_path('.').stat() or { pyrt.fail(err) }.mtime
	println(if stamp > 0 { 'True' } else { 'False' })
	println((count(':memory:', true)).str() + ' ' + (count(':memory:', false)).str())
}
