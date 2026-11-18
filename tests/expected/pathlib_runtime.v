module main

import os
import pyrt.pathlib
import pyrt.pyos
import pyrt

fn data_file(base pathlib.Path, name string) pathlib.Path {
	return base.joinpath('data').joinpath(name)
}

fn describe(p pathlib.Path) string {
	return '${p.name()} in ${p.parent().name()} (${p.suffix()}, ${p.stem()})'
}

fn main_func_py() ! {
	root := pathlib.new_path(pyos.environ_get('TMPDIR', '/tmp')).joinpath('py2v_pathlib_runtime')
	target := data_file(root, 'notes.txt')
	println(if target.exists() { 'True' } else { 'False' })
	target.parent().mkdir(parents: true, exist_ok: true)!
	target.write_text('hello\n')!
	println((if target.exists() { 'True' } else { 'False' }).str() + ' ' + (if target.is_file() {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if target.parent().is_dir() { 'True' } else { 'False' }).str())
	println(target.read_text()!.trim_space())
	println(describe(target))
	other := target.with_suffix('.bak')!
	other.write_text('x')!
	names := (target.parent().iterdir() or { pyrt.fail(err) }).map(it.name()).sorted()
	println(names)
	println(target.parent().glob('*.txt')!.clone().len)
	println(if target.str().ends_with('notes.txt') { 'True' } else { 'False' })
	other.unlink()!
	println(if other.exists() { 'True' } else { 'False' })
	target.unlink()!
	target.parent().rmdir()!
	root.rmdir()!
	println(if root.exists() { 'True' } else { 'False' })
	home := pathlib.home()
	println(if home.is_absolute() { 'True' } else { 'False' })
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
