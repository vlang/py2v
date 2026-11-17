module main

import os
import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

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
	{
		f := managed_file(path)
		return f.read()
	}
}
