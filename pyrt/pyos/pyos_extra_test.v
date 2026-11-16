module pyos

import os
import time
import pyrt

fn test_pyos_splitext_relpath_constants() {
    stem, ext := path_splitext('/a/.hidden.txt')
    // python: __import__('os').path.splitext('/a/.hidden.txt') == ('/a/.hidden','.txt')
    assert stem == '/a/.hidden' && ext == '.txt'
    dotfile, no_ext := path_splitext('.bashrc')
    // python: __import__('os').path.splitext('.bashrc') == ('.bashrc','')
    assert dotfile == '.bashrc' && no_ext == ''
    base, trailing := path_splitext('example.')
    // python: __import__('os').path.splitext('example.') == ('example','.')
    assert base == 'example' && trailing == '.'
    // python: __import__('os').path.relpath('/a/b/c','/a/b') == 'c'
    assert (path_relpath('/a/b/c', '/a/b') or { panic(err.msg()) }) == 'c'
    // python: __import__('os').path.relpath('/a/b','/a/c') == '../b'
    assert (path_relpath('/a/b', '/a/c') or { panic(err.msg()) }) == '../b'
    // python: __import__('os').path.relpath('/a/b','/a/b') == '.'
    assert (path_relpath('/a/b', '/a/b') or { panic(err.msg()) }) == '.'
    // python: __import__('os').sep == '/'
    assert sep == '/'
    // python: __import__('os').linesep in ('\n','\r\n')
    assert linesep == '\n'
}

fn test_pyos_extra_files_and_walk() {
    root := os.join_path(os.vtmp_dir(), 'pyrt_pyos_extra_${time.unix_now()}')
    defer { os.rmdir_all(root) or {} }
    os.mkdir_all(os.join_path(root, 'child'), os.MkdirParams{}) or { panic(err.msg()) }
    src := os.join_path(root, 'child', 'source.txt')
    dest := os.join_path(root, 'child', 'moved.txt')
    os.write_file(src, 'hello') or { panic(err.msg()) }
    // python: fs_result('file.stat().st_size == len("é\\nhello".encode())')
    assert (path_getsize(src) or { panic(err.msg()) }) == 5
    // python: fs_result('file.stat().st_mtime > 0')
    details := stat(src) or { panic(err.msg()) }
    assert details.st_size == 5 && details.mtime > 0
    // python: fs_result('sorted((p.name for p in folder.iterdir())) == ["bytes.bin", "test.txt"]')
    rows := walk(root)
    assert rows.len == 2
    first_dirs := pyrt.getitem(rows[0], pyrt.Value(i64(1))) or { panic(err.msg()) }
    second_files := pyrt.getitem(rows[1], pyrt.Value(i64(2))) or { panic(err.msg()) }
    assert pyrt.repr(first_dirs) == "['child']"
    assert pyrt.repr(second_files) == "['source.txt']"
    // runtime: the limited file-only rename copies then removes; it is NOT atomic.
    rename(src, dest) or { panic(err.msg()) }
    moved_contents := os.read_file(dest) or { panic(err.msg()) }
    assert !os.exists(src) && moved_contents == 'hello'
    // python: fs_result('file.exists() and file.is_file()')
    assert path_isfile(dest)
    // runtime: relpath and realpath return POSIX strings, with symlink handling approximate.
    assert path_realpath(dest) != ''
    // python: __import__('os').cpu_count() is None or __import__('os').cpu_count() > 0
    assert cpu_count() == none
    // runtime: no chdir API supplied; don't silently pretend to change directory.
    chdir(root) or { assert pyrt.caught(err, 'NotImplementedError') != none }
}

fn test_pyos_replace_subset_and_errors() {
    root := os.join_path(os.vtmp_dir(), 'pyrt_pyos_replace_${time.unix_now()}')
    defer { os.rmdir_all(root) or {} }
    os.mkdir_all(root, os.MkdirParams{}) or { panic(err.msg()) }
    first := os.join_path(root, 'a')
    second := os.join_path(root, 'b')
    os.write_file(first, 'left') or { panic(err.msg()) }
    os.write_file(second, 'right') or { panic(err.msg()) }
    replace(first, second) or { panic(err.msg()) }
    // python: exec_result('import tempfile,os; d=tempfile.TemporaryDirectory(); a=os.path.join(d.name,"a");b=os.path.join(d.name,"b");open(a,"w").write("left");open(b,"w").write("right");os.replace(a,b)', 'open(b).read() == "left" and not os.path.exists(a)')
    value := os.read_file(second) or { panic(err.msg()) }
    assert value == 'left' && !os.exists(first)
    // python: error_text(lambda: __import__('os').path.relpath('')) == 'ValueError|no path specified'
    _ = path_relpath('', '.') or { assert pyrt.caught(err, 'ValueError') != none; '' }
}
