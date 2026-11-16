module sqlite3

import os
import pyrt

fn test_row_operator_and_optional_routes() { check_row_operator_and_optional_routes() or { panic(err.msg()) } }
fn check_row_operator_and_optional_routes() ! {
    directory := os.join_path(os.vtmp_dir(), 'pyrt_round5_row_tests')
    os.mkdir_all(directory)!
    defer { os.rmdir_all(directory) or {} }
    conn := connect(os.join_path(directory, 'rows.sqlite'))!
    defer { conn.close() or {} }
    cur := conn.execute("SELECT 'zero' AS title")!
    row := cur.fetchone() or { panic('expected row') }
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', "row[0] == 'zero'")
    assert pyrt.str(row.get_item(pyrt.Value(0))!) == 'zero'
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', "row[-1] == 'zero'")
    assert pyrt.str(row.get_item(pyrt.Value(i64(-1)))!) == 'zero'
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', "row['TITLE'] == 'zero'")
    assert pyrt.str(row.get_item(pyrt.Value('TITLE'))!) == 'zero'
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', "'zero' in row")
    assert row.contains(pyrt.Value('zero'))
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', "'title' not in row")
    assert !row.contains(pyrt.Value('title'))
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', 'bool(row)')
    assert row.bool_()
    // python: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', 'row == row')
    assert row.eq(row)
    // python: sqlite3.connect(':memory:').execute('SELECT 1 WHERE 0').fetchone() is None
    assert cur.fetchone_value() is pyrt.NoneType
    second := conn.execute("SELECT 'zero' AS title")!
    tuple_value := second.fetchone_value()
    // python: tuple(sqlite3.connect(':memory:').execute("SELECT 'zero' AS title").fetchone()) == ('zero',)
    assert pyrt.repr(tuple_value) == "('zero',)"
    // python: sqlite3.connect(':memory:').execute('SELECT 1 WHERE 0').fetchone() is None
    assert second.fetchone_value() is pyrt.NoneType
}
fn row_error_text(key pyrt.Value) string {
    row := Row{cells: [pyrt.Value('zero')], columns: ['title']}
    row.get_item(key) or { return err.msg() }
    return '<no error>'
}
fn test_row_index_errors() {
    // python: error_text(lambda: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', 'row[3]')) == 'IndexError|tuple index out of range'
    assert row_error_text(pyrt.Value(3)) == 'tuple index out of range'
    // python: error_text(lambda: exec_result('import sqlite3;c=sqlite3.connect(\':memory:\');c.row_factory=sqlite3.Row;row=c.execute("SELECT \'zero\' AS title").fetchone()', 'row[1.2]')) == 'IndexError|Index must be int or string'
    assert row_error_text(pyrt.Value(f64(1.2))) == 'Index must be int or string'
}
