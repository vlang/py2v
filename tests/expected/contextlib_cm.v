module main

import os

type Any = bool | int | i64 | f64 | string | []u8

// @contextmanager: unsupported decorator — remove or implement manually
fn managed_file(path Any, ch chan Any) {
	defer { ch.close() }
	f := os.open(path) or { panic(err) }
	defer {
		f.close()
	}
	ch <- f
}

fn open_and_read(path Any) Any {
	if true {
		f := managed_file(path)
		return f.read()
	}
}
