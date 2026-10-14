module main

import os

// TODO(py2v): no V equivalent for import tempfile
// Provide one in python_to_v_import (types.v) or port the module.

// TODO(py2v): no V mapping for tempfile.mktemp
// Each site below is stubbed with a zero value.

type Any = bool | int | i64 | f64 | string | []u8

fn write_and_read() {
	path := Any(0)
	if true {
		mut f := os.create(path) or { panic(err) }
		defer { f.close() }
		f.write('hello world')
	}
	if true {
		mut f := os.open(path) or { panic(err) }
		defer { f.close() }
		data := f.read()
		println(data)
	}
	os.delete(os.index(path))
}

fn nested_files() {
	path1 := 'a.txt'
	path2 := 'b.txt'
	if true {
		mut f1 := os.create(path1) or { panic(err) }
		defer { f1.close() }
		f1.write('file1')
		if true {
			mut f2 := os.create(path2) or { panic(err) }
			defer { f2.close() }
			f2.write('file2')
		}
	}
}

fn main() {
	write_and_read()
	nested_files()
}
