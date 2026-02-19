@[translated]
module main

import os

fn write_and_read() {
	path := tempfile.mktemp()
	if true {
		mut f := os.create(path) or { panic(err) }
		defer { f.close() }
		f.write('hello world')
	}

	if true {
		mut f := os.open(path) or { panic(err) }
		defer { f.close() }
		data := f.read()
		println(data.str())
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
