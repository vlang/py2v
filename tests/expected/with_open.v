@[translated]
module main

import os

fn main() {
	if true {
		temp_file := namedTemporaryFile('a+', false)
		file_path := temp_file.name
		if true {
			mut f := os.create(file_path) or { panic(err) }
			f.write('hello')
		}

		if true {
			mut f := os.open(file_path) or { panic(err) }
			assert f.read(1) == 'h'
			assert f.read() == 'ello'
			println('OK')
		}
	}
}
