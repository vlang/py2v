module tempfile

import os

fn test_mkdtemp_temporary_directory() {
    path := mkdtemp(prefix: 'pyrt-check-') or { panic(err.msg()) }
    defer { os.rmdir_all(path) or {} }
    // python: __import__('tempfile').gettempdir() != ''
    assert gettempdir() != ''
    // python: tempfile_probe('mkdtemp_prefix')
    assert os.base(path)[0 .. 11] == 'pyrt-check-'
    // python: tempfile_probe('mkdtemp_isdir')
    assert os.is_dir(path)
    d := new_temporary_directory(prefix: 'pyrt-auto-') or { panic(err.msg()) }
    name := d.name
    // python: tempfile_probe('tempdir_prefix')
    assert os.base(name)[0 .. 10] == 'pyrt-auto-'
    d.cleanup() or { panic(err.msg()) }
    // python: tempfile_probe('tempdir_cleaned')
    assert !os.exists(name)
}

fn test_mkstemp_pair() {
    mut file, path := mkstemp(prefix: 'pyrt-file-') or { panic(err.msg()) }
    defer { os.rm(path) or {} }
    // python: tempfile_probe('mkstemp_prefix')
    assert os.base(path)[0 .. 10] == 'pyrt-file-'
    _ = file.write_string('abc') or { panic(err.msg()) }
    file.close()
    // python: tempfile_probe('mkstemp_content') == 'abc'
    assert os.read_file(path) or { '' } == 'abc'
}
