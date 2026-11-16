module main

import pyrt.datetime
import pyrt.sqlite3
import pyrt

fn shift(when datetime.Datetime, by datetime.Timedelta) datetime.Datetime {
	return when
}

fn open_db_py(path string) !&sqlite3.Connection {
	return sqlite3.connect(path)!
}

fn open_db(path string) &sqlite3.Connection {
	return open_db_py(path) or { pyrt.fail(err) }
}

fn label(when datetime.Datetime) string {
	return when.isoformat()
}

fn main() {
	println(label(shift((datetime.new_datetime(2024, 5, 6) or { pyrt.fail(err) }), (datetime.timedelta(
		days: 1
	) or { pyrt.fail(err) }))))
	conn := open_db(':memory:')
	println('opened')
}
