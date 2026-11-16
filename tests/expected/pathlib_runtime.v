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

fn main_func() {
	root := pathlib.new_path(pyos.environ_get('TMPDIR', '/tmp')).joinpath('py2v_pathlib_runtime')
	target := data_file(root, 'notes.txt')
	println(if target.exists() { 'True' } else { 'False' })
	target.parent().mkdir(parents: true, exist_ok: true) or { pyrt.fail(err) }
	target.write_text('hello\n') or { pyrt.fail(err) }
	println((if target.exists() { 'True' } else { 'False' }).str() + ' ' + (if target.is_file() {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if target.parent().is_dir() { 'True' } else { 'False' }).str())
	println((target.read_text() or { pyrt.fail(err) }).trim_space())
	println(describe(target))
	other := target.with_suffix('.bak') or { pyrt.fail(err) }
	other.write_text('x') or { pyrt.fail(err) }
	names := (target.parent().iterdir() or { pyrt.fail(err) }).map(it.name()).sorted()
	println(names)
	println((target.parent().glob('*.txt') or { pyrt.fail(err) }).len)
	println(if target.str().ends_with('notes.txt') { 'True' } else { 'False' })
	other.unlink() or { pyrt.fail(err) }
	println(if other.exists() { 'True' } else { 'False' })
	target.unlink() or { pyrt.fail(err) }
	target.parent().rmdir() or { pyrt.fail(err) }
	root.rmdir() or { pyrt.fail(err) }
	println(if root.exists() { 'True' } else { 'False' })
	home := pathlib.home()
	println(if home.is_absolute() { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
