module main

import os

fn main() {
	p := 'data.txt'
	content := os.read_file(p) or { '' }
	os.write_file(p, 'hello world')!
	exists := os.exists(p)
	is_f := os.is_file(p)
	is_d := os.is_dir(p)
	name := os.file_name(p)
	parent := os.dir(p)
	sub := os.join_path(os.dir(p), 'subdir', 'out.txt')
	os.mkdir_all('newdir')!
	os.rm(p)!
	for f in os.ls('.') or { [] } {
		println(f)
	}
	files := os.glob(os.join_path('.', '*.txt')) or { [] }
	println(files)
}
