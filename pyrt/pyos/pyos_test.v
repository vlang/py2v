module pyos

import os
import time
import pyrt

fn test_pyos_path_functions() {
    // python: __import__('os').path.join('/home', 'x', 'y') == '/home/x/y'
    assert path_join('/home', 'x', 'y') == '/home/x/y'
    // python: __import__('os').path.join('a', '/b', 'c') == '/b/c'
    assert path_join('a', '/b', 'c') == '/b/c'
    // python: __import__('os').path.join('a', '', 'b') == 'a/b'
    assert path_join('a', '', 'b') == 'a/b'
    // python: __import__('os').path.dirname('/a/b.txt') == '/a'
    assert path_dirname('/a/b.txt') == '/a'
    // python: __import__('os').path.basename('/a/b.txt') == 'b.txt'
    assert path_basename('/a/b.txt') == 'b.txt'
    // python: __import__('os').path.expanduser('~') == __import__('os').path.expanduser('~')
    assert path_expanduser('~') != ''
    // python: __import__('os').path.isabs(__import__('os').path.abspath('.'))
    assert path_abspath('.')[0] == 47
    // python: __import__('os').path.isdir(__import__('os').getcwd())
    assert path_isdir(getcwd())
    // python: not __import__('os').path.exists('/unlikely_pyrt_no_such_entry_4569087012')
    assert !path_exists('/unlikely_pyrt_no_such_entry_4569087012')
}

fn test_pyos_filesystem_and_environment() {
    // runtime: use the same real local temporary directory for all operations.
    root := os.join_path(os.vtmp_dir(), 'pyrt_pyos_${time.unix_now()}')
    defer { os.rmdir_all(root) or {} }
    makedirs(path_join(root, 'a', 'b'), false) or { panic(err.msg()) }
    // python: __import__('os').path.isdir(__import__('os').getcwd())
    assert path_isdir(path_join(root, 'a', 'b'))
    // python: error_text(lambda: __import__('os').makedirs('/tmp',exist_ok=True)) == '<no error>'
    makedirs(path_join(root, 'a', 'b'), true) or { panic(err.msg()) }
    os.write_file(path_join(root, 'a', 'note.txt'), 'text') or { panic(err.msg()) }
    // python: sorted(['note.txt','b']) == ['b','note.txt']
    names := listdir(path_join(root, 'a')) or { panic(err.msg()) }
    assert 'note.txt' in names && 'b' in names
    // python: __import__('os').path.isfile(__file__) if '__file__' in globals() else True
    assert path_isfile(path_join(root, 'a', 'note.txt'))
    remove(path_join(root, 'a', 'note.txt')) or { panic(err.msg()) }
    assert !path_exists(path_join(root, 'a', 'note.txt'))
    rmdir(path_join(root, 'a', 'b')) or { panic(err.msg()) }
    assert !path_exists(path_join(root, 'a', 'b'))
    // python: __import__('os').getenv('PYRT_UNLIKELY_NONEXISTENT_41919018') is None
    assert getenv('PYRT_UNLIKELY_NONEXISTENT_41919018') == none
    // python: __import__('os').getenv('PYRT_UNLIKELY_NONEXISTENT_41919018','fallback') == 'fallback'
    assert environ_get('PYRT_UNLIKELY_NONEXISTENT_41919018', 'fallback') == 'fallback'
    assert getenv_or('PYRT_UNLIKELY_NONEXISTENT_41919018', 'fallback') == 'fallback'
    // runtime: environ() is a copy of the process environment, not os.environ's live mapping.
    _ = environ()
    _ = getpid() or { assert pyrt.caught(err, 'NotImplementedError') != none; 0 }
}
