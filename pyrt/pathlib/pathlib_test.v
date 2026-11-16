module pathlib

import os
import pyrt

fn test_pathlib_pure_path_operations() {
    check_pure_path_operations() or { assert false, err.msg() }
}

fn check_pure_path_operations() ! {
    // python: str(__import__('pathlib').Path()) == '.'
    assert new_path().str() == '.'
    // python: str(__import__('pathlib').Path('a//b/./c')) == 'a/b/c'
    assert new_path('a//b/./c').str() == 'a/b/c'
    // python: str(__import__('pathlib').Path('/a/b', '/q/r')) == '/q/r'
    assert new_path('/a/b', '/q/r').str() == '/q/r'
    // python: str(__import__('pathlib').Path('a/b').parent) == 'a'
    assert new_path('a/b').parent().str() == 'a'
    // python: str(__import__('pathlib').Path('a').parent) == '.'
    assert new_path('a').parent().str() == '.'
    // python: str(__import__('pathlib').Path('/').parent) == '/'
    assert new_path('/').parent().str() == '/'
    // python: __import__('pathlib').Path('/a/b.txt').name == 'b.txt'
    assert new_path('/a/b.txt').name() == 'b.txt'
    // python: __import__('pathlib').Path('/a/b.tar.gz').stem == 'b.tar'
    assert new_path('/a/b.tar.gz').stem() == 'b.tar'
    // python: __import__('pathlib').Path('/a/b.tar.gz').suffix == '.gz'
    assert new_path('/a/b.tar.gz').suffix() == '.gz'
    // python: __import__('pathlib').Path('.bashrc').suffix == ''
    assert new_path('.bashrc').suffix() == ''
    // python: str(__import__('pathlib').Path('a/b.txt').with_name('c.md')) == 'a/c.md'
    assert new_path('a/b.txt').with_name('c.md')!.str() == 'a/c.md'
    // python: str(__import__('pathlib').Path('a/b.txt').with_suffix('.md')) == 'a/b.md'
    assert new_path('a/b.txt').with_suffix('.md')!.str() == 'a/b.md'
    // python: str(__import__('pathlib').Path('a/b.txt').with_suffix('')) == 'a/b'
    assert new_path('a/b.txt').with_suffix('')!.str() == 'a/b'
    // python: str(__import__('pathlib').Path('a') / 'b') == 'a/b'
    assert (new_path('a') / new_path('b')).str() == 'a/b'
    // python: str(__import__('pathlib').Path('a').joinpath('b', 'c')) == 'a/b/c'
    assert new_path('a').joinpath('b', 'c').str() == 'a/b/c'
    // python: str(__import__('pathlib').Path('/a/b/c').relative_to('/a')) == 'b/c'
    assert new_path('/a/b/c').relative_to(new_path('/a'))!.str() == 'b/c'
    // python: __import__('pathlib').Path('/a/b').is_relative_to('/a') is True
    assert new_path('/a/b').is_relative_to(new_path('/a'))
    // python: __import__('pathlib').Path('/a/b').is_relative_to('/b') is False
    assert !new_path('/a/b').is_relative_to(new_path('/b'))
    // python: __import__('pathlib').Path('/a').parts == ('/', 'a')
    assert new_path('/a').parts() == ['/', 'a']
    // python: __import__('pathlib').Path('/a').is_absolute() is True
    assert new_path('/a').is_absolute()
    // python: __import__('pathlib').Path('a').is_absolute() is False
    assert !new_path('a').is_absolute()
    // python: __import__('pathlib').Path.home().is_absolute() is True
    assert home().is_absolute()
    // python: __import__('pathlib').Path.cwd().is_absolute() is True
    assert cwd().is_absolute()
    // python: str(__import__('pathlib').Path('~/a').expanduser()).endswith('/a') is True
    assert expanduser_test()!
}

fn expanduser_test() !bool {
    path := new_path('~/a').expanduser()!
    text := path.str()
    return text.len >= 2 && text[text.len - 2 .. text.len] == '/a'
}

fn test_pathlib_disk_io() {
    check_disk_io() or { assert false, err.msg() }
}

fn check_disk_io() ! {
    root := new_path(os.join_path(os.vtmp_dir(), 'pyrt_pathlib_v_test'))
    defer { os.rmdir_all(root.str()) or {} }
    root.mkdir(MkdirOptions{parents: true, exist_ok: true})!
    folder := root.joinpath('one', 'two')
    folder.mkdir(MkdirOptions{parents: true})!
    // python: __import__('pathlib').Path('one/two').name == 'two'
    assert folder.name() == 'two'
    // python: len('é\nhello') == 7
    count := folder.joinpath('test.txt').write_text('é\nhello')!
    assert count == 7
    file := folder.joinpath('test.txt')
    // python: fs_result('file.is_file()') is True
    assert file.is_file()
    // python: fs_result('file.exists()') is True
    assert file.exists()
    // python: fs_result('file.is_dir()') is False
    assert !file.is_dir()
    // python: 'é\nhello' == 'é\nhello'
    assert file.read_text()! == 'é\nhello'
    // python: 'é\nhello'.encode('utf-8') == bytes([195,169,10,104,101,108,108,111])
    assert file.read_bytes()! == [u8(195), u8(169), u8(10), u8(104), u8(101), u8(108), u8(108), u8(111)]
    // python: len(b'abc') == 3
    assert folder.joinpath('bytes.bin').write_bytes([u8(97), u8(98), u8(99)])! == 3
    // python: bytes([97,98,99]) == b'abc'
    assert folder.joinpath('bytes.bin').read_bytes()! == [u8(97), u8(98), u8(99)]
    // python: fs_result('file.stat().st_size') == 8
    assert file.stat()!.st_size == 8
    // python: fs_result('file.stat().st_mtime') > 0
    assert file.stat()!.mtime > 0.0
    // python: fs_result('file.samefile(file)') is True
    assert file.samefile(file)!
    mut opened := file.open(OpenOptions{})!
    opened.close()
    // python: fs_result('sorted(p.name for p in folder.iterdir())') == ['bytes.bin','test.txt']
    mut names := []string{}
    for entry in folder.iterdir()! { names << entry.name() }
    assert names.len == 2
    // python: fs_result("len(list(folder.glob('*.txt')))") == 1
    assert folder.glob('*.txt')!.len == 1
    // python: fs_result("len(list(root.rglob('*.txt')))") == 1
    assert root.rglob('*.txt')!.len == 1
    // python: pathlib.Path('file').resolve().is_absolute() is True
    assert file.resolve().is_absolute()
    file.unlink(UnlinkOptions{})!
    // python: pathlib.Path('file').exists() is False  # after unlink
    assert !file.exists()
    file.unlink(UnlinkOptions{missing_ok: true})!
    folder.joinpath('bytes.bin').unlink(UnlinkOptions{})!
    folder.rmdir()!
    root.joinpath('one').rmdir()!
}

fn test_pathlib_errors_and_touch() {
    check_errors_and_touch() or { assert false, err.msg() }
}

fn check_errors_and_touch() ! {
    root := new_path(os.join_path(os.vtmp_dir(), 'pyrt_pathlib_error_test'))
    defer { os.rmdir_all(root.str()) or {} }
    root.mkdir(MkdirOptions{parents: true, exist_ok: true})!
    absent := root.joinpath('absent')
    // python: pathlib.Path('not-there').exists() is False
    assert !absent.exists()
    // python: error_text(lambda: fs_result("file.parent.joinpath('absent').read_text()")).startswith('FileNotFoundError|')
    message := path_error_text(absent)
    assert message.contains('FileNotFoundError|[Errno 2] No such file or directory:')
    absent.touch(TouchOptions{})!
    // python: fs_touch_result('file.is_file()') is True
    assert absent.is_file()
    // python: fs_touch_result('file.stat().st_size') == 0
    assert absent.stat()!.st_size == 0
    // python: fs_touch_result('file.touch(exist_ok=True)') is None
    absent.touch(TouchOptions{})!
    // python: error_text(lambda: fs_touch_result('file.touch(exist_ok=False)')).startswith('FileExistsError|')
    absent.touch(TouchOptions{exist_ok: false}) or {
        assert err is pyrt.PyError
        if err is pyrt.PyError { assert err.class_name == 'FileExistsError' }
        return
    }
    assert false, 'expected FileExistsError'
}

fn path_error_text(p Path) string {
    _ = p.read_text() or {
        if err is pyrt.PyError { return err.class_name + '|' + err.msg() }
        return 'VError|' + err.msg()
    }
    return '<no error>'
}
