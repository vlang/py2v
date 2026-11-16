module pyrt

// Direct, result-returning operations for the common dynamically typed cases.
// as_str(Value) and as_list(Value) already exist in convert.v; they are NOT
// redeclared here. Dynamic wrappers in the user's dyn.v are preserved.

// Retains the dictionary object (unlike as_list, which returns a snapshot).
pub fn as_dict(v Value) !&Dict {
    if v is &Dict { return v }
    return raise('TypeError', 'expected dict, got ${type_name(v)}')
}

pub fn dict_keys(v Value) ![]Value {
    d := as_dict(v)!
    return d.keys.clone()
}

pub fn dict_items(v Value) ![]Value {
    d := as_dict(v)!
    mut out := []Value{}
    for key in d.keys {
        hash := hash_key(key)!
        item := d.values[hash] or { none_ }
        pair := new_tuple([key, item])
        out << Value(pair)
    }
    return out
}

pub fn dict_values(v Value) ![]Value {
    d := as_dict(v)!
    mut out := []Value{}
    for key in d.keys {
        hash := hash_key(key)!
        item := d.values[hash] or { none_ }
        out << item
    }
    return out
}

// Non-result dict.get: a missing key returns the supplied default; a non-dict
// or unhashable key raises the same exception path as the existing dyn.v.
pub fn get(v Value, key Value, default_value Value) Value {
    if v is &Dict {
        hash := hash_key(key) or { fail(err) }
        return v.values[hash] or { default_value }
    }
    fail(raise('AttributeError', "'${type_name(v)}' object has no attribute 'get'"))
}

// The following helpers avoid the dynamic name dispatch in call_method().
// They deliberately use the existing, tested implementations of Unicode
// casing, splitting, joining and replacement without invoking V's native
// byte-oriented string methods.
pub fn lower(v Value) !Value {
    source := as_str(v)!
    return Value(case_convert(source, 'lower'))
}

pub fn upper(v Value) !Value {
    source := as_str(v)!
    return Value(case_convert(source, 'upper'))
}

pub fn strip(v Value) !Value {
    source := as_str(v)!
    return Value(strip_side(source, none_, 'both')!)
}

pub fn strip_chars(v Value, chars Value) !Value {
    source := as_str(v)!
    return Value(strip_side(source, chars, 'both')!)
}

pub fn split(v Value) !Value {
    source := as_str(v)!
    parts := split_text(source, none_, -1, false)!
    return Value(new_list(parts))
}

pub fn split_sep(v Value, separator Value) !Value {
    source := as_str(v)!
    parts := split_text(source, separator, -1, false)!
    return Value(new_list(parts))
}

pub fn split_n(v Value, separator Value, maxsplit int) !Value {
    source := as_str(v)!
    parts := split_text(source, separator, maxsplit, false)!
    return Value(new_list(parts))
}

pub fn startswith(v Value, prefix Value) !bool {
    source := as_str(v)!
    return starts_or_ends(source, prefix, [prefix], false)!
}

pub fn endswith(v Value, suffix Value) !bool {
    source := as_str(v)!
    return starts_or_ends(source, suffix, [suffix], true)!
}

pub fn replace(v Value, old Value, replacement Value) !Value {
    source := as_str(v)!
    old_string := need_str(old)!
    new_string := need_str(replacement)!
    return Value(text_replace(source, old_string, new_string, -1))
}

pub fn replace_n(v Value, old Value, replacement Value, count int) !Value {
    source := as_str(v)!
    old_string := need_str(old)!
    new_string := need_str(replacement)!
    return Value(text_replace(source, old_string, new_string, count))
}

pub fn join(v Value, iterable Value) !Value {
    separator := as_str(v)!
    elements := iter(iterable)!
    mut parts := []string{}
    for i, item in elements {
        if item !is string {
            return raise('TypeError', 'sequence item ${i}: expected str instance, ${type_name(item)} found')
        }
        parts << item
    }
    return Value(parts.join(separator))
}

// Dict view equivalents are snapshots, as in the existing method dispatcher.
pub fn keys(v Value) !Value {
    items := dict_keys(v)!
    return Value(new_list(items))
}

pub fn values(v Value) !Value {
    items := dict_values(v)!
    return Value(new_list(items))
}

pub fn items(v Value) !Value {
    pairs := dict_items(v)!
    return Value(new_list(pairs))
}

// Mixed-type tuples: build Value(&Tuple) in the current module, not a V
// multiple-return value, and do not expose mutable array backing storage.
pub fn tuple_of(values ...Value) Value {
    result := new_tuple(values)
    return Value(result)
}

pub fn tuple_item(v Value, index int) !Value {
    if v !is &Tuple { return raise('TypeError', 'expected tuple, got ${type_name(v)}') }
    position := Value(i64(index))
    return getitem(v, position)!
}

pub fn tuple_items(v Value) ![]Value {
    if v is &Tuple { return v.items.clone() }
    return raise('TypeError', 'expected tuple, got ${type_name(v)}')
}

// Python unpacking accepts any iterable, not just tuples. The explicit
// expected count lets py2v generate the correct ValueError before assignments.
pub fn unpack(v Value, expected int) ![]Value {
    pieces := iter(v)!
    if pieces.len < expected {
        return raise('ValueError', 'not enough values to unpack (expected ${expected}, got ${pieces.len})')
    }
    if pieces.len > expected {
        return raise('ValueError', 'too many values to unpack (expected ${expected})')
    }
    return pieces
}

// Closure creation does not invoke right(). This preserves Python's lazy
// `or`/`and`, including return of the original operand rather than a bool.
// py2v must materialize the LEFT operand before constructing/invoking the
// helper; C does not define argument evaluation order for arbitrary calls.
pub fn either_lazy(left Value, right fn () Value) Value {
    if truth(left) { return left }
    return right()
}

pub fn both_lazy(left Value, right fn () Value) Value {
    if !truth(left) { return left }
    return right()
}
