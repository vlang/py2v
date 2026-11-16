module pyrt

// These are explicit interop conversions, NOT implementations of Python's
// int(), float(), str(), or bool() parsing/coercion constructors. Returned
// arrays are snapshots; nested reference-backed Python objects stay shared.
pub fn from_int(v int) Value {
	return Value(i64(v))
}

pub fn from_float(v f64) Value {
	return Value(v)
}

pub fn from_str(v string) Value {
	return Value(v)
}

pub fn from_bool(v bool) Value {
	return Value(v)
}

pub fn from_strings(v []string) Value {
	mut items := []Value{}
	for item in v {
		items << Value(item)
	}
	return Value(new_list(items))
}

pub fn from_ints(v []int) Value {
	mut items := []Value{}
	for item in v {
		items << Value(i64(item))
	}
	return Value(new_list(items))
}

// The insertion order here is the order V exposes when iterating this map.
// To supply a known order, call new_dict() followed by setitem() in that order.
pub fn from_map(v map[string]Value) Value {
	mut keys := []Value{}
	mut values := map[string]Value{}
	for name, item in v {
		keys << Value(name)
		values['s' + name] = item
	}
	return Value(&Dict{keys: keys, values: values})
}

pub fn as_int(v Value) !i64 {
	if v is int {
		return i64(v)
	}
	if v is i64 {
		return v
	}
	if v is bool {
		return if v { i64(1) } else { i64(0) }
	}
	return raise('TypeError', 'expected int, got ${type_name(v)}')
}

pub fn as_float(v Value) !f64 {
	if is_numeric(v) {
		return numeric_float(v)
	}
	return raise('TypeError', 'expected float, got ${type_name(v)}')
}

pub fn as_str(v Value) !string {
	if v is string {
		return v
	}
	return raise('TypeError', 'expected str, got ${type_name(v)}')
}

pub fn as_bool(v Value) !bool {
	if v is bool {
		return v
	}
	return raise('TypeError', 'expected bool, got ${type_name(v)}')
}

pub fn as_list(v Value) ![]Value {
	if v is &List {
		return v.items.clone()
	}
	if v is Sequence {
		mut out := []Value{}
		for i in 0 .. v.len() {
			out << v.get(i)!
		}
		return out
	}
	return raise('TypeError', 'expected list, got ${type_name(v)}')
}

pub fn as_strings(v Value) ![]string {
	items := as_list(v)!
	mut out := []string{}
	for item in items {
		out << as_str(item)!
	}
	return out
}

// Raw Value([]u8) boxing transfers a read-only view by convention. These
// helpers isolate storage when the producer or consumer may mutate its array.
pub fn from_bytes(v []u8) Value {
	return Value(v.clone())
}

pub fn as_bytes(v Value) ![]u8 {
	if v is []u8 { return v.clone() }
	return raise('TypeError', 'expected bytes, got ${type_name(v)}')
}
