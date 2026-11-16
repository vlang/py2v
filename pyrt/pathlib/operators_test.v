module pathlib



fn test_path_operator_routes() {
    a := new_path('a', 'b')
    b := new_path('a', 'c')
    // python: str(pathlib.Path('a')/pathlib.Path('b')) == 'a/b'
    assert new_path('a').divide(new_path('b')).str() == 'a/b'
    // python: pathlib.Path('a/b') == pathlib.Path('a/./b')
    assert a.eq(new_path('a/./b'))
    // python: pathlib.Path('a/b') < pathlib.Path('a/c')
    assert a.lt(b)
    // python: pathlib.Path('a/b') <= pathlib.Path('a/b')
    assert a.le(a)
    // python: pathlib.Path('a/c') > pathlib.Path('a/b')
    assert b.gt(a)
    // python: pathlib.Path('a/c') >= pathlib.Path('a/c')
    assert b.ge(b)
    // python: pathlib.Path('a') < pathlib.Path('a/b')
    assert new_path('a').compare(a) == -1
    // python: bool(pathlib.Path('.'))
    assert new_path().bool_()
}
