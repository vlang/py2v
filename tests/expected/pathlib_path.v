module main

import os
import pyrt.pathlib
import pyrt

fn main() {
	p := pathlib.new_path('data.txt')
	content := p.read_text() or { pyrt.fail(err) }
	p.write_text('hello world') or { pyrt.fail(err) }
	exists := p.exists()
	is_f := p.is_file()
	is_d := p.is_dir()
	name := p.name()
	parent := p.parent()
	sub := p.parent().joinpath('subdir').joinpath('out.txt')
	pathlib.new_path('newdir').mkdir(parents: true, exist_ok: true) or { pyrt.fail(err) }
	p.unlink() or { pyrt.fail(err) }
	for f in pathlib.new_path('.').iterdir() or { pyrt.fail(err) } {
		println(f)
	}
	files := pathlib.new_path('.').glob('*.txt') or { pyrt.fail(err) }
	println(files)
}
