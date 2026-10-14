module main

import os

// TODO(py2v): no V equivalent for import tempfile
// Provide one in python_to_v_import (types.v) or port the module.

fn main() {
	if true {
		temp_file := namedTemporaryFile('a+', false)
		file_path := temp_file.name
		if true {
			mut f := os.create(file_path) or { panic(err) }
			defer { f.close() }
			f.write('hello')
		}
		if true {
			mut f := os.open(file_path) or { panic(err) }
			defer { f.close() }
			assert f.read(1) == 'h'
			assert f.read() == 'ello'
			println('OK')
		}
	}
}
