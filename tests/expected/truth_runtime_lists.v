module main

import regex
import pyrt.sqlite3
import pyrt.re
import pyrt

fn main() {
	connection := (sqlite3.connect(':memory:') or { pyrt.fail(err) })
	rows := (connection.execute('SELECT 1') or { pyrt.fail(err) }).fetchall()
	empty := (connection.execute('SELECT 1 WHERE 0') or { pyrt.fail(err) }).fetchall()
	if rows.len > 0 {
		println('rows')
	}
	println(if !(rows.len > 0) { 'True' } else { 'False' })
	println(if !(empty.len > 0) { 'True' } else { 'False' })
	println(if empty.len > 0 { 1 } else { 0 })
	for rows.len > 0 {
		println('once')
		break
	}
	if (connection.execute('SELECT 1') or { pyrt.fail(err) }).fetchall().len > 0 {
		println('call')
	}
	cursor := connection.execute('SELECT 1') or { pyrt.fail(err) }
	if cursor.fetchmany(1).len > 0 {
		println('many')
	}
	println(if !(cursor.fetchmany(1).len > 0) { 'True' } else { 'False' })
	connection.close() or { pyrt.fail(err) }
	if (re.findall('x', 'x', 0) or { pyrt.fail(err) }).len > 0 {
		println('findall')
	}
	println(if !((re.findall('x', '', 0) or { pyrt.fail(err) }).len > 0) { 'True' } else { 'False' })
	pattern := (re.compile('x', 0) or { pyrt.fail(err) })
	if pattern.findall('x').len > 0 {
		println('pattern-findall')
	}
	if (re.split('x', 'x', 0, 0) or { pyrt.fail(err) }).len > 0 {
		println('split')
	}
	if (pattern.split('x', 0) or { pyrt.fail(err) }).len > 0 {
		println('pattern-split')
	}
}
