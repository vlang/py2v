module shutil

import os
import time

fn test_copy_and_move_and_remove() {
    root := os.join_path(os.vtmp_dir(), 'pyrt-shutil-${time.now().unix_nano()}')
    os.mkdir_all(root, os.MkdirParams{}) or { panic(err.msg()) }
    defer { os.rmdir_all(root) or {} }
    source := os.join_path(root, 'source.txt')
    os.write_file(source, 'test') or { panic(err.msg()) }
    copied := copy(source, os.join_path(root, 'copy.txt')) or { panic(err.msg()) }
    // python: shutil_probe('copy_basename') == 'copy.txt'
    assert os.base(copied) == 'copy.txt'
    // python: shutil_probe('copy_content') == 'test'
    assert os.read_file(copied) or { '' } == 'test'
    moved := move(copied, os.join_path(root, 'moved.txt')) or { panic(err.msg()) }
    // python: shutil_probe('move_basename') == 'moved.txt'
    assert os.base(moved) == 'moved.txt'
    // python: shutil_probe('move_source_gone')
    assert !os.exists(copied)
    // python: shutil_probe('move_content') == 'test'
    assert os.read_file(moved) or { '' } == 'test'
    nested := os.join_path(root, 'nested')
    os.mkdir_all(nested, os.MkdirParams{}) or { panic(err.msg()) }
    rmtree(nested) or { panic(err.msg()) }
    // python: shutil_probe('rmtree_gone')
    assert !os.exists(nested)
}

fn test_which_and_copytree() {
    // python: __import__('shutil').which('sh') is not None
    assert (which('sh') or { '' }) != ''
    root := os.join_path(os.vtmp_dir(), 'pyrt-shutil-tree-${time.now().unix_nano()}')
    os.mkdir_all(root, os.MkdirParams{}) or { panic(err.msg()) }
    defer { os.rmdir_all(root) or {} }
    source := os.join_path(root, 'original')
    os.mkdir_all(source, os.MkdirParams{}) or { panic(err.msg()) }
    os.write_file(os.join_path(source, 'x'), 'Y') or { panic(err.msg()) }
    destination := copytree(source, os.join_path(root, 'copied'), CopytreeOptions{}) or { panic(err.msg()) }
    // python: shutil_probe('copytree_basename') == 'copied'
    assert os.base(destination) == 'copied'
    // python: shutil_probe('copytree_content') == 'Y'
    assert os.read_file(os.join_path(destination, 'x')) or { '' } == 'Y'
}

fn test_copyfile_samefile_error() {
    root := os.join_path(os.vtmp_dir(), 'pyrt-shutil-same-${time.now().unix_nano()}')
    os.mkdir_all(root, os.MkdirParams{}) or { panic(err.msg()) }
    defer { os.rmdir_all(root) or {} }
    a := os.join_path(root, 'same.txt')
    os.write_file(a, 'x') or { panic(err.msg()) }
    mut message := ''
    _ = copyfile(a, a) or { message = err.msg(); '' }
    // python: __import__('shutil').SameFileError.__mro__[1] is __import__('shutil').Error
    assert message.contains('same file')
}
