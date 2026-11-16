module sqlite3

import db.sqlite
import pyrt
import pyrt.json as pyjson

// sqlite3.Row in assignment context lowers to the constant `sqlite3.row`.
// The returned row representation remains Row regardless of this flag.
pub const row = true

// Exception-name constants for `pyrt.caught(err, sqlite3.integrity_error)`.
// These are not Python exception class objects; translated except handlers
// must use pyrt.caught rather than `is` on a V type.
pub const error_class = 'sqlite3.Error'
pub const warning = 'sqlite3.Warning'
pub const interface_error = 'sqlite3.InterfaceError'
pub const database_error = 'sqlite3.DatabaseError'
pub const data_error = 'sqlite3.DataError'
pub const operational_error = 'sqlite3.OperationalError'
pub const integrity_error = 'sqlite3.IntegrityError'
pub const internal_error = 'sqlite3.InternalError'
pub const programming_error = 'sqlite3.ProgrammingError'
pub const not_supported_error = 'sqlite3.NotSupportedError'

// db.sqlite's supplied public API has no sqlite3_stmt bind/column-type calls.
// Parameters are rendered as type-safe SQL *literals*: strings through a UTF-8
// hex literal CAST, binary through a BLOB X'' literal, and None through NULL.
// The SELECT wrapper uses SQLite typeof/hex/printf to recover each result
// VALUE storage class with synthetic CTE column names. See limitations.

struct State {
mut:
    db             sqlite.DB
    closed         bool
    in_transaction bool
    total_changes  int
    lastrowid      i64
}

pub struct Connection {
    state &State
pub mut:
    // A py2v lowering of `conn.row_factory = sqlite3.Row` can set this true.
    // Cursor results in this wrapper are ALWAYS Row records, even when false.
    row_factory bool
}

pub struct Row {
    columns []string
    cells   []pyrt.Value
}

pub fn (r Row) len() int {
    return r.cells.len
}

pub fn (r Row) keys() []string {
    return r.columns.clone()
}

// The specified non-result return type cannot raise IndexError; an invalid
// index returns None. by_name returns KeyError for a missing column.
pub fn (r Row) get(i int) pyrt.Value {
    index := if i < 0 { i + r.cells.len } else { i }
    if index < 0 || index >= r.cells.len { return pyrt.none_ }
    return r.cells[index]
}

pub fn (r Row) by_name(name string) !pyrt.Value {
    target := ascii_lower(name)
    for i, column in r.columns {
        if ascii_lower(column) == target { return r.cells[i] }
    }
    return pyrt.raise('IndexError', 'No item with that key')
}

pub fn (r Row) as_tuple() pyrt.Value {
    return pyrt.Value(pyrt.new_tuple(r.cells))
}

pub struct Cursor {
    connection &Connection
pub mut:
    arraysize int = 1
    lastrowid i64
    rowcount  int = -1
mut:
    rows     []Row
    position int
}

pub fn (c &Cursor) fetchone() ?Row {
    if c.position >= c.rows.len { return none }
    at := c.position
    unsafe { c.position = at + 1 }
    return c.rows[at]
}

pub fn (c &Cursor) fetchmany(n int) []Row {
    mut count := n
    if count < 0 { count = c.rows.len - c.position }
    mut out := []Row{}
    for _ in 0 .. count {
        fetched_row := c.fetchone() or { break }
        out << fetched_row
    }
    return out
}

pub fn (c &Cursor) fetchall() []Row {
    return c.fetchmany(-1)
}

pub fn (c &Cursor) iter() []Row {
    // Snapshot; Python cursors themselves are iterators.
    return c.fetchall()
}

pub fn (c &Cursor) execute(query string, params ...pyrt.Value) !&Cursor {
    fresh := c.connection.execute(query, ...params)!
    unsafe {
        c.rows = fresh.rows.clone()
        c.position = 0
        c.rowcount = fresh.rowcount
        c.lastrowid = fresh.lastrowid
    }
    return c
}

pub fn (c &Cursor) executemany(query string, parameter_sets []pyrt.Value) !&Cursor {
    fresh := c.connection.executemany(query, parameter_sets)!
    unsafe {
        c.rows = fresh.rows.clone()
        c.position = 0
        c.rowcount = fresh.rowcount
        c.lastrowid = fresh.lastrowid
    }
    return c
}

fn register_sqlite_errors() {
    pyrt.register_exception('sqlite3.Error', ['Exception'])
    pyrt.register_exception('sqlite3.Warning', ['Exception'])
    pyrt.register_exception('sqlite3.InterfaceError', ['sqlite3.Error'])
    pyrt.register_exception('sqlite3.DatabaseError', ['sqlite3.Error'])
    pyrt.register_exception('sqlite3.DataError', ['sqlite3.DatabaseError'])
    pyrt.register_exception('sqlite3.OperationalError', ['sqlite3.DatabaseError'])
    pyrt.register_exception('sqlite3.IntegrityError', ['sqlite3.DatabaseError'])
    pyrt.register_exception('sqlite3.InternalError', ['sqlite3.DatabaseError'])
    pyrt.register_exception('sqlite3.ProgrammingError', ['sqlite3.DatabaseError'])
    pyrt.register_exception('sqlite3.NotSupportedError', ['sqlite3.DatabaseError'])
}

// V's db.sqlite appends a numeric result code and SQL statement. Python's
// sqlite3 exceptions expose only SQLite's message, so strip that wrapper.
fn sqlite_message(raw string) string {
    mut at := 0
    for {
        open := raw.index_after(' (', at) or { return raw }
        close := raw.index_after(') (', open) or { return raw }
        code := raw[open + 2..close]
        if code.len > 0 && code.bytes().all(it >= `0` && it <= `9`) {
            return raw[..open]
        }
        at = open + 2
    }
    return raw
}

fn sqlite_error(raw string) IError {
    register_sqlite_errors()
    message := sqlite_message(raw)
    lower := ascii_lower(message)
    if lower.contains('constraint failed') || lower.contains('unique constraint') || lower.contains('foreign key constraint') {
        return pyrt.raise('sqlite3.IntegrityError', message)
    }
    if lower.contains('bind') || lower.contains('parameter') || lower.contains('closed database') {
        return pyrt.raise('sqlite3.ProgrammingError', message)
    }
    return pyrt.raise('sqlite3.OperationalError', message)
}

pub fn connect(path string) !&Connection {
    register_sqlite_errors()
    raw := sqlite.connect(path) or { return sqlite_error(err.msg()) }
    _ = raw.busy_timeout(5000)
    return &Connection{
        state: &State{db: raw, total_changes: 0}
    }
}

fn (conn &Connection) checked_state() !&State {
    if conn.state.closed { return sqlite_error('Cannot operate on a closed database.') }
    return conn.state
}

pub fn (conn &Connection) cursor() &Cursor {
    return &Cursor{connection: conn, rows: []Row{}, rowcount: -1}
}

pub fn (conn &Connection) lastrowid() i64 {
    return conn.state.lastrowid
}

pub fn (conn &Connection) total_changes() int {
    return conn.state.total_changes
}

pub fn (conn &Connection) commit() ! {
    mut state := conn.checked_state()!
    if state.in_transaction {
        _ = state.db.exec('COMMIT') or { return sqlite_error(err.msg()) }
        state.in_transaction = false
    }
}

pub fn (conn &Connection) rollback() ! {
    mut state := conn.checked_state()!
    if state.in_transaction {
        _ = state.db.exec('ROLLBACK') or { return sqlite_error(err.msg()) }
        state.in_transaction = false
    }
}

pub fn (conn &Connection) close() ! {
    mut state := conn.state
    if !state.closed {
        state.db.close() or { return sqlite_error(err.msg()) }
        state.closed = true
    }
}

fn ascii_lower(text string) string {
    abc := 'abcdefghijklmnopqrstuvwxyz'
    mut out := ''
    for i in 0 .. text.len {
        byte := text[i]
        if byte >= 65 && byte <= 90 { out = out + abc[int(byte) - 65 .. int(byte) - 64] }
        else { out = out + text[i .. i + 1] }
    }
    return out
}

fn space(b u8) bool {
    return b == 32 || b == 9 || b == 10 || b == 13
}

fn trimmed(s string) string {
    mut start := 0
    mut stop := s.len
    for start < stop && space(s[start]) { start = start + 1 }
    for stop > start && space(s[stop - 1]) { stop = stop - 1 }
    return s[start .. stop]
}

fn word_start(s string) string {
    value := trimmed(s)
    mut i := 0
    for i < value.len && !space(value[i]) && value[i] != 40 { i = i + 1 }
    return ascii_lower(value[0 .. i])
}

fn hex_data(text string) string {
    chars := '0123456789ABCDEF'
    mut out := ''
    for i in 0 .. text.len {
        b := int(text[i])
        out = out + chars[b / 16 .. b / 16 + 1] + chars[b % 16 .. b % 16 + 1]
    }
    return out
}

fn hex_bytes(bytes []u8) string {
    chars := '0123456789ABCDEF'
    mut out := ''
    for byte in bytes {
        b := int(byte)
        out = out + chars[b / 16 .. b / 16 + 1] + chars[b % 16 .. b % 16 + 1]
    }
    return out
}

fn parse_blob(hex string) []u8 {
    mut out := []u8{}
    mut i := 0
    for i + 1 < hex.len {
        high := hex_nibble(hex[i])
        low := hex_nibble(hex[i + 1])
        out << u8(high * 16 + low)
        i = i + 2
    }
    return out
}

fn hex_nibble(byte u8) int {
    if byte >= 48 && byte <= 57 { return int(byte) - 48 }
    if byte >= 65 && byte <= 70 { return int(byte) - 55 }
    if byte >= 97 && byte <= 102 { return int(byte) - 87 }
    return 0
}

fn bind_literal(value pyrt.Value) !string {
    match value {
        pyrt.NoneType { return 'NULL' }
        i64 { return value.str() }
        int { return value.str() }
        bool { return if value { '1' } else { '0' } }
        f64 {
            s := pyrt.repr(value)
            if s == 'nan' { return 'NULL' }
            if s == 'inf' { return '1e999' }
            if s == '-inf' { return '-1e999' }
            return s
        }
        string { return "CAST(X'" + hex_data(value) + "' AS TEXT)" }
        []u8 { return "X'" + hex_bytes(value) + "'" }
        else { return sqlite_error("Error binding parameter: type '${pyrt.type_name(value)}' is not supported") }
    }
}

struct BindParams {
    named      pyrt.Value = pyrt.none_
    positional []pyrt.Value
    is_named   bool
}

fn is_param_sequence(v pyrt.Value) bool {
    return match v {
        &pyrt.List, &pyrt.Tuple, pyrt.Sequence { true }
        else { false }
    }
}

fn normalize_params(params []pyrt.Value) !BindParams {
    if params.len == 1 {
        v := params[0]
        if v is &pyrt.Dict { return BindParams{named: v, is_named: true} }
        if is_param_sequence(v) {
            return BindParams{positional: pyrt.iter(v)!}
        }
    }
    return BindParams{positional: params.clone()}
}

fn binding_name_byte(b u8) bool {
    return (b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b == 95
}

// This lexer is intentionally conservative. Placeholder tokens inside single/
// double quotes, bracketed identifiers, -- comments, and /* */ comments are
// never substituted. Named binds use bare dictionary keys as in CPython.
fn render_params(query string, params []pyrt.Value) !string {
    bindings := normalize_params(params)!
    mut out := ''
    mut position := 0
    mut consumed := 0
    mut mode := 0 // 0 SQL, 1 single, 2 double, 3 bracket, 4 line comment, 5 block
    for position < query.len {
        b := query[position]
        next := if position + 1 < query.len { query[position + 1] } else { u8(0) }
        if mode == 1 || mode == 2 {
            out = out + query[position .. position + 1]
            if (mode == 1 && b == 39) || (mode == 2 && b == 34) {
                if next == b {
                    out = out + query[position + 1 .. position + 2]
                    position = position + 2
                    continue
                }
                mode = 0
            }
            position = position + 1
            continue
        }
        if mode == 3 {
            out = out + query[position .. position + 1]
            if b == 93 { mode = 0 }
            position = position + 1
            continue
        }
        if mode == 4 {
            out = out + query[position .. position + 1]
            if b == 10 { mode = 0 }
            position = position + 1
            continue
        }
        if mode == 5 {
            out = out + query[position .. position + 1]
            if b == 42 && next == 47 {
                out = out + '/'
                position = position + 2
                mode = 0
                continue
            }
            position = position + 1
            continue
        }
        if b == 39 { mode = 1 }
        else if b == 34 { mode = 2 }
        else if b == 91 { mode = 3 }
        else if b == 45 && next == 45 { mode = 4 }
        else if b == 47 && next == 42 { mode = 5 }
        if mode != 0 {
            out = out + query[position .. position + 1]
            position = position + 1
            continue
        }
        if b == 63 {
            if bindings.is_named { return sqlite_error('Binding 1 has no name, but you supplied a dictionary (which has only names).') }
            if next >= 48 && next <= 57 { return sqlite_error('Numbered ?NNN placeholders are not supported by pyrt.sqlite3') }
            if consumed >= bindings.positional.len { return sqlite_error('Incorrect number of bindings supplied. The current statement uses more bindings than provided.') }
            out = out + bind_literal(bindings.positional[consumed])!
            consumed = consumed + 1
            position = position + 1
            continue
        }
        if (b == 58 || b == 64 || b == 36) && binding_name_byte(next) {
            mut stop := position + 1
            for stop < query.len && binding_name_byte(query[stop]) { stop = stop + 1 }
            name := query[position + 1 .. stop]
            if !bindings.is_named { return sqlite_error('Binding ${consumed + 1} has no name, but you supplied a sequence') }
            value := pyrt.getitem(bindings.named, pyrt.Value(name)) or { return sqlite_error('You did not supply a value for binding parameter :${name}.') }
            out = out + bind_literal(value)!
            position = stop
            continue
        }
        out = out + query[position .. position + 1]
        position = position + 1
    }
    if !bindings.is_named && consumed != bindings.positional.len {
        return sqlite_error('Incorrect number of bindings supplied. The current statement uses ${consumed}, and there are ${bindings.positional.len} supplied.')
    }
    return out
}

fn quote_ident(name string) string {
    mut out := '"'
    for i in 0 .. name.len {
        if name[i] == 34 { out = out + '""' }
        else { out = out + name[i .. i + 1] }
    }
    return out + '"'
}

// Scan SELECT fields/keyword outside SQL strings and parens. This is not a
// complete SQLite SQL parser; unreadable column layouts take the fallback.
fn from_at(query string) int {
    lower := ascii_lower(query)
    mut i := 0
    mut depth := 0
    mut quoted := u8(0)
    for i < query.len {
        b := query[i]
        if quoted != 0 {
            if b == quoted {
                if i + 1 < query.len && query[i + 1] == b { i = i + 2; continue }
                quoted = 0
            }
            i = i + 1
            continue
        }
        if b == 39 || b == 34 { quoted = b; i = i + 1; continue }
        if b == 40 { depth = depth + 1 }
        if b == 41 { depth = depth - 1 }
        if depth == 0 && i + 6 <= query.len && lower[i .. i + 6] == ' from ' { return i }
        i = i + 1
    }
    return -1
}

fn split_fields(source string) []string {
    mut out := []string{}
    mut start := 0
    mut depth := 0
    mut quoted := u8(0)
    mut i := 0
    for i < source.len {
        b := source[i]
        if quoted != 0 {
            if b == quoted {
                if i + 1 < source.len && source[i + 1] == b { i = i + 2; continue }
                quoted = 0
            }
            i = i + 1
            continue
        }
        if b == 39 || b == 34 { quoted = b; i = i + 1; continue }
        if b == 40 { depth = depth + 1 }
        if b == 41 { depth = depth - 1 }
        if depth == 0 && b == 44 {
            out << trimmed(source[start .. i])
            start = i + 1
        }
        i = i + 1
    }
    out << trimmed(source[start .. source.len])
    return out
}

fn table_after_from(query string, at int) string {
    if at < 0 { return '' }
    mut pos := at + 6
    for pos < query.len && space(query[pos]) { pos = pos + 1 }
    if pos >= query.len { return '' }
    if query[pos] == 34 {
        pos = pos + 1
        start := pos
        for pos < query.len && query[pos] != 34 { pos = pos + 1 }
        return query[start .. pos]
    }
    start := pos
    for pos < query.len && !space(query[pos]) && query[pos] != 59 { pos = pos + 1 }
    return query[start .. pos]
}

fn alias_name(field string) string {
    text := trimmed(field)
    lower := ascii_lower(text)
    mut i := 0
    mut found := -1
    for i + 4 <= lower.len {
        if lower[i .. i + 4] == ' as ' { found = i }
        i = i + 1
    }
    if found >= 0 { return unquote_ident(trimmed(text[found + 4 .. text.len])) }
    // A qualified expression "t.column" yields "column" in SQLite results.
    mut separator := -1
    for j in 0 .. text.len { if text[j] == 46 { separator = j } }
    if separator >= 0 && !text.contains('(') && !text.contains(' ') {
        return unquote_ident(text[separator + 1 .. text.len])
    }
    return unquote_ident(text)
}

fn unquote_ident(text string) string {
    if text.len >= 2 && ((text[0] == 34 && text[text.len - 1] == 34) || (text[0] == 91 && text[text.len - 1] == 93)) {
        return text[1 .. text.len - 1]
    }
    return text
}

fn select_column_names(query string, mut state State) []string {
    lower := ascii_lower(trimmed(query))
    if !lower.contains('select') { return []string{} }
    mut start := 0
    for start + 6 <= query.len {
        if ascii_lower(query[start .. start + 6]) == 'select' { break }
        start = start + 1
    }
    if start + 6 > query.len { return []string{} }
    from_index := from_at(query)
    projection_end := if from_index >= 0 { from_index } else { query.len }
    mut projection := trimmed(query[start + 6 .. projection_end])
    lowered_projection := ascii_lower(projection)
    if lowered_projection.len >= 9 && lowered_projection[0 .. 9] == 'distinct ' { projection = trimmed(projection[9 .. projection.len]) }
    fields := split_fields(projection)
    mut names := []string{}
    for field in fields {
        if field == '*' || (field.len >= 2 && field[field.len - 2 .. field.len] == '.*') {
            table := table_after_from(query, from_index)
            if table == '' || table[0] == 40 { return []string{} }
            rows := state.db.exec('PRAGMA table_info(' + quote_ident(table) + ')') or { return []string{} }
            if rows.len == 0 { return []string{} }
            for r in rows {
                cols := r.values()
                if cols.len < 2 { return []string{} }
                names << cols[1]
            }
        } else { names << alias_name(field) }
    }
    return names
}

fn row_from_raw(values []string, names []string) Row {
    mut columns := []string{}
    mut cells := []pyrt.Value{}
    for i, text in values {
        columns << if i < names.len { names[i] } else { 'column${i}' }
        cells << pyrt.Value(text)
    }
    return Row{columns: columns, cells: cells}
}

fn row_from_typed(values []string, names []string) Row {
    mut cells := []pyrt.Value{}
    for i, _ in names {
        type_name := values[i * 3]
        text := values[i * 3 + 1]
        hex := values[i * 3 + 2]
        if type_name == 'null' { cells << pyrt.none_ }
        else if type_name == 'integer' {
            cells << (pyjson.loads(text) or { pyrt.Value(text) })
        } else if type_name == 'real' {
            // SQLite printf('%.17g',1.0) yields '1'. Keep Python float.
            mut number := text
            if !number.contains('.') && !number.contains('e') && !number.contains('E') {
                number = number + '.0'
            }
            cells << (pyjson.loads(number) or { pyrt.Value(text) })
        } else if type_name == 'blob' { cells << pyrt.Value(parse_blob(hex)) }
        else { cells << pyrt.Value(text) }
    }
    return Row{columns: names.clone(), cells: cells}
}

// SQLite typeof() interrogates each VALUE's storage class. A synthetic
// column-name list avoids dependence on the original projection's spelling:
// SELECT 1, SELECT 41 + 1, duplicate aliases, and quoted expression names all
// work identically. SQLite does not expose sqlite3_column_type via the supplied
// V db.sqlite interface, so this is SQL-level introspection rather than C API
// typed binding/column inspection.
//
// MATERIALIZED keeps random()/other volatile expressions from being evaluated
// separately by each typeof/CAST/hex probe. Requires SQLite >= 3.35.0.
fn typed_sql(query string, count int) string {
    mut aliases := []string{}
    mut expressions := []string{}
    for i in 0 .. count {
        name := 'pyrt_value_${i}'
        aliases << quote_ident(name)
        column := 'q.' + quote_ident(name)
        expressions << 'typeof(' + column + ')'
        expressions << "CASE WHEN typeof(" + column + ") = 'real' THEN printf('%.17g', " + column + ") WHEN typeof(" + column + ") = 'blob' THEN '' ELSE CAST(" + column + ' AS TEXT) END'
        expressions << 'hex(' + column + ')'
    }
    clean := trimmed(query)
    statement := if clean.len > 0 && clean[clean.len - 1] == 59 {
        trimmed(clean[0 .. clean.len - 1])
    } else { clean }
    mut wrapped := 'WITH pyrt_typed(' + aliases.join(', ') + ') AS MATERIALIZED ('
    wrapped = wrapped + statement + ') SELECT '
    wrapped = wrapped + expressions.join(', ') + ' FROM pyrt_typed AS q'
    return wrapped
}

fn typed_result(mut state State, query string, given_names []string, count int) ?[]Row {
    if count <= 0 || count > 1024 { return none }
    mut names := []string{}
    for i in 0 .. count {
        if i < given_names.len {
            names << given_names[i]
        } else {
            names << 'column${i}'
        }
    }
    typed_rows := state.db.exec(typed_sql(query, count)) or { return none }
    mut out := []Row{}
    for raw in typed_rows {
        values := raw.values()
        if values.len != count * 3 { return none }
        out << row_from_typed(values, names)
    }
    return out
}

fn read_query(mut state State, query string) ![]Row {
    names := select_column_names(query, mut state)
    // Preferred path: ONE SQLite execution with SQL storage classes annotated.
    // Known projection count allows us to avoid running a volatile query twice.
    if names.len > 0 {
        if typed := typed_result(mut state, query, names, names.len) {
            return typed
        }
    }
    raw_rows := state.db.exec(query) or { return sqlite_error(err.msg()) }
    if raw_rows.len == 0 { return []Row{} }
    // For SELECT * over joins, aliases, and other projections that our simple
    // parser cannot count, the V wrapper exposes only string cells. The first
    // raw row reveals the true column COUNT, allowing a second, typed query.
    // A second execution may see changed nondeterministic results; callers
    // must not use this fallback for side-effecting SELECT expressions.
    actual_count := raw_rows[0].values().len
    if actual_count != names.len {
        if typed := typed_result(mut state, query, names, actual_count) {
            return typed
        }
    }
    mut out := []Row{}
    for raw in raw_rows { out << row_from_raw(raw.values(), names) }
    return out
}

fn is_dml(word string) bool {
    return word == 'insert' || word == 'update' || word == 'delete' || word == 'replace'
}

pub fn (conn &Connection) execute(query string, params ...pyrt.Value) !&Cursor {
    mut state := conn.checked_state()!
    rendered := render_params(query, params)!
    command := word_start(rendered)
    if is_dml(command) && !state.in_transaction {
        _ = state.db.exec('BEGIN') or { return sqlite_error(err.msg()) }
        state.in_transaction = true
    }
    rows := read_query(mut state, rendered)!
    if command == 'begin' || command == 'savepoint' { state.in_transaction = true }
    if command == 'commit' || command == 'rollback' { state.in_transaction = false }
    affected := state.db.get_affected_rows_count()
    state.total_changes = state.db.q_int('SELECT total_changes()') or { state.total_changes }
    state.lastrowid = state.db.last_insert_rowid()
    count := if is_dml(command) { affected } else { -1 }
    return &Cursor{
        connection: conn
        rows: rows
        position: 0
        rowcount: count
        lastrowid: state.lastrowid
    }
}

pub fn (conn &Connection) executemany(query string, parameter_sets []pyrt.Value) !&Cursor {
    mut total := 0
    for set in parameter_sets {
        next := conn.execute(query, set)!
        if next.rowcount > 0 { total = total + next.rowcount }
    }
    return &Cursor{connection: conn, rows: []Row{}, rowcount: total, lastrowid: 0}
}

fn split_script(script string) []string {
    mut out := []string{}
    mut start := 0
    mut quote := u8(0)
    mut i := 0
    for i < script.len {
        b := script[i]
        if quote != 0 {
            if b == quote {
                if i + 1 < script.len && script[i + 1] == quote { i = i + 2; continue }
                quote = 0
            }
        } else if b == 39 || b == 34 { quote = b }
        else if b == 59 {
            part := trimmed(script[start .. i])
            if part != '' { out << part }
            start = i + 1
        }
        i = i + 1
    }
    last := trimmed(script[start .. script.len])
    if last != '' { out << last }
    return out
}

pub fn (conn &Connection) executescript(script string) !&Cursor {
    conn.commit()!
    mut state := conn.checked_state()!
    for statement in split_script(script) {
        _ = state.db.exec(statement) or { return sqlite_error(err.msg()) }
    }
    state.total_changes = state.db.q_int('SELECT total_changes()') or { state.total_changes }
    state.lastrowid = state.db.last_insert_rowid()
    return &Cursor{connection: conn, rows: []Row{}, rowcount: -1, lastrowid: state.lastrowid}
}
