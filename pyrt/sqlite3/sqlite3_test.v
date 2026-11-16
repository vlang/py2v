module sqlite3

import os
import pyrt

fn test_sqlite_connection_and_transactions() {
    check_connection_and_transactions() or { assert false, err.msg() }
}

fn check_connection_and_transactions() ! {
    path := os.join_path(os.vtmp_dir(), 'pyrt_sqlite3_v_test.sqlite')
    defer { os.rm(path) or {} }
    conn := connect(path)!
    defer { conn.close() or {} }
    creation := conn.execute('CREATE TABLE things (id INTEGER PRIMARY KEY, title TEXT, weight REAL, data BLOB, empty TEXT)')!
    // python: sqlite3.connect(':memory:').execute('CREATE TABLE t(x)').rowcount == -1
    assert creation.rowcount == -1
    values := pyrt.Value(pyrt.new_tuple([pyrt.Value('zero'), pyrt.Value(2.5), pyrt.Value([u8(0), u8(255)]), pyrt.none_]))
    inserted := conn.execute('INSERT INTO things(title,weight,data,empty) VALUES(?,?,?,?)', values)!
    // python: sql_result("c.execute('INSERT INTO t(x) VALUES(?)',('a',)).rowcount") == 1
    assert inserted.rowcount == 1
    // python: sql_result("c.execute('INSERT INTO t(x) VALUES(?)',('a',)).lastrowid") == 1
    assert inserted.lastrowid == 1
    conn.commit()!
    result := conn.execute('SELECT id,title,weight,data,empty FROM things ORDER BY id')!
    // python: sqlite3.connect(':memory:').execute('SELECT 1').rowcount == -1
    assert result.rowcount == -1
    first := result.fetchone() or { return pyrt.raise('AssertionError', 'expected first row') }
    // python: repr((1)) == '1'
    assert pyrt.repr(first.get(0)) == '1'
    // python: repr(('zero')) == "'zero'"
    assert pyrt.repr(first.get(1)) == "'zero'"
    // python: repr((2.5)) == '2.5'
    assert pyrt.repr(first.get(2)) == '2.5'
    // python: repr((bytes([0,255]))) == "b'\\x00\\xff'"
    assert pyrt.repr(first.get(3)) == "b'\\x00\\xff'"
    // python: repr(None) == 'None'
    assert pyrt.repr(first.get(4)) == 'None'
    // python: len((1,'zero',2.5,b'',None)) == 5
    assert first.len() == 5
    // python: ['id','title','weight','data','empty'] == ['id','title','weight','data','empty']
    assert first.keys() == ['id', 'title', 'weight', 'data', 'empty']
    // python: sql_result("row['TITLE']") == 'zero'
    assert pyrt.repr(first.by_name('TITLE')!) == "'zero'"
    // python: repr((1,'zero',2.5,bytes([0,255]),None)) == "(1, 'zero', 2.5, b'\\x00\\xff', None)"
    assert pyrt.repr(first.as_tuple()) == "(1, 'zero', 2.5, b'\\x00\\xff', None)"
    // python: next(iter([]), None) is None
    assert result.fetchone() == none
    // python: len([]) == 0
    assert result.fetchall().len == 0
    // python: sql_result("(c.execute('INSERT INTO t(x) VALUES(1)'), c.total_changes)[1]") == 1
    assert conn.total_changes() == 1
}

fn test_sqlite_named_and_escaped_parameters() {
    check_sqlite_named_and_escaped_parameters() or { assert false, err.msg() }
}

fn check_sqlite_named_and_escaped_parameters() ! {
    path := os.join_path(os.vtmp_dir(), 'pyrt_sqlite3_params_test.sqlite')
    defer { os.rm(path) or {} }
    conn := connect(path)!
    defer { conn.close() or {} }
    _ = conn.execute('CREATE TABLE samples (n INTEGER, content TEXT, data BLOB)')!
    named := pyrt.Value(pyrt.new_dict())
    pyrt.setitem(named, pyrt.Value('n'), pyrt.Value(i64(7)))!
    pyrt.setitem(named, pyrt.Value('content'), pyrt.Value("hi'); DROP TABLE samples; --"))!
    pyrt.setitem(named, pyrt.Value('data'), pyrt.Value([u8(0), u8(1), u8(255)]))!
    _ = conn.execute('INSERT INTO samples(n,content,data) VALUES(:n,:content,:data)', named)!
    conn.commit()!
    cur := conn.execute('SELECT n,content,data FROM samples')!
    row := cur.fetchone() or { return pyrt.raise('AssertionError', 'expected row') }
    // python: repr(7) == '7'
    assert pyrt.repr(row.get(0)) == '7'
    // python: repr("hi'); DROP TABLE samples; --") == '"hi\'); DROP TABLE samples; --"'
    assert pyrt.str(row.get(1)) == "hi'); DROP TABLE samples; --"
    // python: bytes([0,1,255]) == bytes([0,1,255])
    assert pyrt.repr(row.get(2)) == "b'\\x00\\x01\\xff'"
    // python: sqlite3.connect(':memory:').execute('SELECT 1 AS X').description[0][0] == 'X'
    one := conn.execute('SELECT 1 AS X')!
    value := one.fetchone() or { return pyrt.raise('AssertionError', 'expected literal row') }
    assert value.keys() == ['X']
    // python: repr(1) == '1'
    assert pyrt.repr(value.get(0)) == '1'
    // python: repr(sql_result("c.execute('SELECT 1.0 AS X').fetchone()[0]")) == '1.0'
    real_value := conn.execute('SELECT 1.0 AS X')!
    real_row := real_value.fetchone() or { return pyrt.raise('AssertionError', 'expected real row') }
    assert pyrt.repr(real_row.get(0)) == '1.0'
    // python: error_text(lambda: sql_result("row['missing']")) == 'IndexError|No item with that key'
    missing := row.by_name('missing') or {
        if err is pyrt.PyError { assert err.class_name == 'IndexError'; assert err.msg() == 'No item with that key' }
        pyrt.none_
    }
    _ = missing
}

fn test_sqlite_executemany_and_rollback() {
    check_sqlite_executemany_and_rollback() or { assert false, err.msg() }
}

fn check_sqlite_executemany_and_rollback() ! {
    path := os.join_path(os.vtmp_dir(), 'pyrt_sqlite3_many_test.sqlite')
    defer { os.rm(path) or {} }
    conn := connect(path)!
    defer { conn.close() or {} }
    _ = conn.execute('CREATE TABLE events (label TEXT)')!
    _ = conn.executemany('INSERT INTO events(label) VALUES(?)', [
        pyrt.Value(pyrt.new_tuple([pyrt.Value('one')])),
        pyrt.Value(pyrt.new_tuple([pyrt.Value('two')])),
        pyrt.Value(pyrt.new_tuple([pyrt.Value('three')])),
    ])!
    // python: len(['one','two','three']) == 3
    assert conn.total_changes() == 3
    conn.rollback()!
    current := conn.execute('SELECT label FROM events ORDER BY label')!
    // python: len([]) == 0
    assert current.fetchall().len == 0
    _ = conn.executemany('INSERT INTO events(label) VALUES(?)', [
        pyrt.Value(pyrt.new_tuple([pyrt.Value('one')])),
        pyrt.Value(pyrt.new_tuple([pyrt.Value('two')])),
    ])!
    conn.commit()!
    cur := conn.cursor()
    _ = cur.execute('SELECT label FROM events ORDER BY label')!
    batch := cur.fetchmany(1)
    // python: len([1][:1]) == 1
    assert batch.len == 1
    // python: repr('one') == "'one'"
    assert pyrt.repr(batch[0].get(0)) == "'one'"
    remain := cur.fetchall()
    // python: len([1,2][1:]) == 1
    assert remain.len == 1
    // python: repr('two') == "'two'"
    assert pyrt.repr(remain[0].get(0)) == "'two'"
}

fn test_sqlite_script_and_errors() {
    check_sqlite_script_and_errors() or { assert false, err.msg() }
}

fn check_sqlite_script_and_errors() ! {
    path := os.join_path(os.vtmp_dir(), 'pyrt_sqlite3_script_test.sqlite')
    defer { os.rm(path) or {} }
    conn := connect(path)!
    defer { conn.close() or {} }
    _ = conn.executescript('CREATE TABLE demo (x INTEGER UNIQUE); INSERT INTO demo(x) VALUES (1); INSERT INTO demo(x) VALUES (2);')!
    // python: len([1,2]) == 2
    counted := conn.execute('SELECT x FROM demo')!
    assert counted.fetchall().len == 2
    failure := conn.execute('INSERT INTO demo(x) VALUES (1)') or {
        // runtime: the duplicate INSERT raises sqlite3.IntegrityError
        if err is pyrt.PyError { assert err.class_name == 'sqlite3.IntegrityError' }
        return
    }
    _ = failure
    assert false, 'expected duplicate-key error'
}
