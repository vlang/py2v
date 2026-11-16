module sqlite3

import pyrt

// Opt-in lowering for a dynamically used fetchone result. This loses row
// column-name access, so keep fetchone() ?Row for statically typed Row code.
pub fn (c &Cursor) fetchone_value() pyrt.Value {
    if row_value := c.fetchone() { return row_value.as_tuple() }
    return pyrt.none_
}

pub fn (r Row) get_item(key pyrt.Value) !pyrt.Value {
    if key is string { return r.by_name(key)! }
    if key is int || key is i64 || key is bool {
        raw := pyrt.as_int(key)!
        index := if raw < 0 { raw + i64(r.cells.len) } else { raw }
        if index < 0 || index >= i64(r.cells.len) { return pyrt.raise('IndexError', 'tuple index out of range') }
        return r.cells[int(index)]
    }
    return pyrt.raise('IndexError', 'Index must be int or string')
}
pub fn (r Row) contains(item pyrt.Value) bool {
    for cell in r.cells { if pyrt.eq(cell, item) { return true } }
    return false
}
pub fn (r Row) bool_() bool { return r.cells.len > 0 }
pub fn (r Row) eq(other Row) bool {
    if r.columns != other.columns || r.cells.len != other.cells.len { return false }
    for i, cell in r.cells { if !pyrt.eq(cell, other.cells[i]) { return false } }
    return true
}
