module main

import os
import pyrt

type Any = pyrt.Value

// @contextmanager: unsupported decorator — remove or implement manually
fn managed_file(ch chan Any, path Any) {
	defer { ch.close() }
	f := os.open(path) or { panic(err) }
	defer {
		f.close()
	}
	ch <- f
}

fn open_and_read(path Any) Any {
	{
		f := managed_file(path)
		return f.read()
	}
}
