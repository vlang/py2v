module sqlite3

// must_row is the row of a `fetchone()` result that Python code indexes without a test:
// indexing None raises a TypeError there.
pub fn must_row(r ?Row) Row {
	return r or { panic("TypeError: 'NoneType' object is not subscriptable") }
}
