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

fn label(when datetime.Datetime) string {
	return when.isoformat()
}

fn py2v_entry1() ! {
	println(label(shift(datetime.new_datetime(2024, 5, 6)!, datetime.timedelta(days: 1)!)))
	conn := open_db_py(':memory:')!
	println('opened')
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
