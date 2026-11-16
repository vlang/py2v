module pyrt

// Values are shallow handles. Mutable containers are always reference backed.
// Construct dictionaries and sets through these helpers or setitem: their
// indexes contain canonical keys, not repr(key).
pub struct NoneType {}

pub struct List {
mut:
	identity i64
pub mut:
	items []Value
}

// The element array is private: exposing an immutable array header would still
// allow a caller to alias its storage. Use new_tuple(), getitem(), and iter().
// The constructor clones the array; element objects themselves remain shared.
pub struct Tuple {
	items []Value
mut:
	identity i64
}

pub struct Dict {
mut:
	identity i64
pub mut:
	keys   []Value
	values map[string]Value
}

// Set iteration is insertion ordered in this runtime, NOT CPython table order.
pub struct Set {
mut:
	identity i64
pub mut:
	items []Value
	index map[string]bool
	// FrozenSet deliberately shares the existing Set Value variant.
	frozen bool
}

// ec510e2: do not perform interface-to-interface casts inside a sum type.
// An Instance returns zero if it cannot provide stable identity.
pub interface Instance {
    class_name() string
    getattr(name string) !Value
    pyrt_identity() i64
mut:
    setattr(name string, v Value) !
}

// Typed sequences supply identity and deletion as required methods. A fixed-
// length sequence can return NotImplementedError from delete().
pub interface Sequence {
    len() int
    get(i int) !Value
    pyrt_identity() i64
mut:
    set(i int, v Value) !
    delete(i int) !
}

pub struct IntList {
mut:
	identity i64
pub mut:
	items []int
}

pub fn (l &IntList) len() int {
	return l.items.len
}

pub fn (l &IntList) get(i int) !Value {
	j := checked_index(i64(i), l.items.len, 'list index out of range')!
	return Value(i64(l.items[j]))
}

pub fn (mut l IntList) set(i int, v Value) ! {
	j := checked_index(i64(i), l.items.len, 'list assignment index out of range')!
	if v is int {
		l.items[j] = v
		return
	}
	if v is i64 {
		l.items[j] = int(v)
		return
	}
	if v is int { l.items[j] = v; return }
	return raise('TypeError', 'int list holds ${type_name(v)}')
}

pub fn (mut l IntList) delete(i int) ! {
	j := checked_index(i64(i), l.items.len, 'list assignment index out of range')!
	mut replacement := []int{}
	for k, item in l.items {
		if k != j {
			replacement << item
		}
	}
	l.items = replacement.clone()
}

pub fn (l &IntList) pyrt_identity() i64 {
	if l.identity == 0 {
		unsafe { l.identity = identity_token() }
	}
	return l.identity
}

// A simple attribute-bearing implementation, useful before a translated class
// supplies its own Instance implementation. name is a Python class name.
pub struct Object {
mut:
	identity i64
pub mut:
	name   string
	fields map[string]Value
}

pub fn (o &Object) class_name() string {
	return o.name
}

pub fn (o &Object) getattr(name string) !Value {
	return o.fields[name] or {
		return raise('AttributeError', "'${o.name}' object has no attribute '${name}'")
	}
}

pub fn (mut o Object) setattr(name string, v Value) ! {
	o.fields[name] = v
}

pub fn (o &Object) pyrt_identity() i64 {
	if o.identity == 0 {
		unsafe { o.identity = identity_token() }
	}
	return o.identity
}

pub struct Function {
	identity i64
pub:
	name string
	call fn (args []Value) !Value = unsafe { nil }
}

pub type Value = Function | Instance | NoneType | Sequence | []u8 | bool | f64 | i64 | int | string | &Dict | &List | &Set | &Tuple

pub const none_ = Value(NoneType{})

pub fn new_list(items []Value) &List {
	return &List{items: items.clone()}
}

pub fn new_tuple(items []Value) &Tuple {
	return &Tuple{items: items.clone()}
}

pub fn new_dict() &Dict {
	return &Dict{keys: []Value{}, values: map[string]Value{}}
}

pub fn new_set(items []Value) !&Set {
	out := &Set{items: []Value{}, index: map[string]bool{}}
	for item in items {
		out.add(item)!
	}
	return out
}

pub fn frozenset_of(values []Value) !Value {
    mut result := new_set(values)!
    unsafe { result.frozen = true }
    return Value(result)
}

pub fn new_object(class_name string) &Object {
	return &Object{name: class_name, fields: map[string]Value{}}
}

// Use this factory rather than a Function literal when function identity matters.
pub fn function(name string, callback fn (args []Value) !Value) Value {
	return Value(Function{identity: identity_token(), name: name, call: callback})
}

pub fn (s &Set) add(item Value) ! {
    if s.frozen { return raise('AttributeError', "'frozenset' object has no attribute 'add'") }
	key := hash_key(item)!
	if key !in s.index {
		unsafe {
			s.items << item
			s.index[key] = true
		}
	}
}

pub fn (s &Set) discard(item Value) ! {
    if s.frozen { return raise('AttributeError', "'frozenset' object has no attribute 'discard'") }
	key := hash_key(item)!
	if key !in s.index {
		return
	}
	mut items := []Value{}
	mut index := map[string]bool{}
	for old in s.items {
		old_key := hash_key(old)!
		if old_key != key {
			items << old
			index[old_key] = true
		}
	}
	unsafe {
		s.items = items.clone()
		s.index = index
	}
}

pub fn type_name(v Value) string {
	return match v {
		NoneType { 'NoneType' }
		bool { 'bool' }
		i64 { 'int' }
		int { 'int' }
		f64 { 'float' }
		string { 'str' }
		[]u8 { 'bytes' }
		&List, Sequence { 'list' }
		&Tuple { 'tuple' }
		&Dict { 'dict' }
		&Set { if v.frozen { 'frozenset' } else { 'set' } }
		Instance { v.class_name() }
		Function { 'function' }
	}
}

pub fn truth(v Value) bool {
	return match v {
		NoneType { false }
		bool { v }
		i64 { v != 0 }
		int { v != 0 }
		f64 { v != 0.0 }
		string { v.len > 0 }
		[]u8 { v.len > 0 }
		&List { v.items.len > 0 }
		Sequence { v.len() > 0 }
		&Tuple { v.items.len > 0 }
		&Dict { v.values.len > 0 }
		&Set { v.items.len > 0 }
		Instance, Function { true }
	}
}

pub fn len_(v Value) !int {
	match v {
		string { return utf8_parts(v).len }
		[]u8 { return v.len }
		&List { return v.items.len }
		Sequence { return v.len() }
		&Tuple { return v.items.len }
		&Dict { return v.values.len }
		&Set { return v.items.len }
		else { return raise('TypeError', "object of type '${type_name(v)}' has no len()") }
	}
}

pub fn iter(v Value) ![]Value {
	match v {
		&List { return v.items.clone() }
		&Tuple { return v.items.clone() }
		&Dict { return v.keys.clone() }
		&Set { return v.items.clone() }
		Sequence {
			mut out := []Value{}
			for i in 0 .. v.len() {
				out << v.get(i)!
			}
			return out
		}
		string {
			mut out := []Value{}
			for ch in utf8_parts(v) {
				out << Value(ch)
			}
			return out
		}
		[]u8 {
			mut out := []Value{}
			for b in v {
				out << Value(i64(b))
			}
			return out
		}
		else { return raise('TypeError', "'${type_name(v)}' object is not iterable") }
	}
}

pub fn getattr(v Value, name string) !Value {
	if v is Instance {
		return v.getattr(name)!
	}
	if v is Function {
		if name == '__name__' {
			return Value(v.name)
		}
	}
	return raise('AttributeError', "'${type_name(v)}' object has no attribute '${name}'")
}

pub fn setattr(v Value, name string, value Value) ! {
	if v is Instance {
		mut instance := unsafe { v }
		instance.setattr(name, value)!
		return
	}
	return raise('AttributeError', "'${type_name(v)}' object has no attribute '${name}' and no __dict__ for setting new attributes")
}

pub fn call(f Value, args []Value) !Value {
	if f is Function {
		return f.call(args)!
	}
	return raise('TypeError', "'${type_name(f)}' object is not callable")
}

fn value_identity(v Value) i64 {
	match v {
		&List {
			if v.identity == 0 {
				unsafe { v.identity = identity_token() }
			}
			return v.identity
		}
		&Tuple {
			if v.identity == 0 {
				unsafe { v.identity = identity_token() }
			}
			return v.identity
		}
		&Dict {
			if v.identity == 0 {
				unsafe { v.identity = identity_token() }
			}
			return v.identity
		}
		&Set {
			if v.identity == 0 {
				unsafe { v.identity = identity_token() }
			}
			return v.identity
		}
		Function { return v.identity }
		Instance { return v.pyrt_identity() }
		Sequence { return v.pyrt_identity() }
		else {}
	}
	return 0
}

// Support modules can use this for CPython-like circular-reference checks.
// Zero means the variant has no accessible stable identity.
pub fn object_identity(v Value) i64 {
    return value_identity(v)
}
