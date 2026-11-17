module main

import os
import pyrt.pathlib
import pyrt.sqlite3
import pyrt

fn path_state(value ?pathlib.Path) {
	println(if value != none { 1 } else { 0 })
	println(if !(value != none) { 'True' } else { 'False' })
	for value != none {
		println('path-loop')
		break
	}
}

fn connection_state(value ?&sqlite3.Connection) {
	println(if value != none { 1 } else { 0 })
	println(if !(value != none) { 'True' } else { 'False' })
}

fn cursor_state(value ?&sqlite3.Cursor) {
	println(if value != none { 1 } else { 0 })
	println(if !(value != none) { 'True' } else { 'False' })
}

fn main() {
	path_state(none)
	path_state(pathlib.new_path(''))
	path_state(pathlib.new_path('not-a-real-file'))
	connection_state(none)
	connection := (sqlite3.connect(':memory:') or { pyrt.fail(err) })
	connection_state(connection)
	cursor_state(none)
	cursor := connection.cursor()
	cursor_state(cursor)
	connection.close() or { pyrt.fail(err) }
	connection_state(connection)
	cursor_state(cursor)
}
