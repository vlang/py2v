module pyrt

// The forms translated code uses on a value of unknown type. py2v's functions do not
// return results yet, so a Python exception raised here stops the program with its message.

// item_at is `v[key]`.
pub fn item_at(v Value, key Value) Value {
	return getitem(v, key) or { panic(err) }
}

// set_index is `v[key] = item`.
pub fn set_index(v Value, key Value, item Value) {
	setitem(v, key, item) or { panic(err) }
}

// slice_of is `v[lo:hi]`; a bound that is None is left out.
pub fn slice_of(v Value, lo Value, hi Value) Value {
	return getslice(v, slice_bound(lo), slice_bound(hi), none) or { panic(err) }
}

fn slice_bound(v Value) ?int {
	if v is NoneType {
		return none
	}
	return to_int(v)
}

// plus, minus, times, over and modulo are `a + b`, `a - b`, `a * b`, `a / b` and `a % b`.
pub fn plus(a Value, b Value) Value {
	return add(a, b) or { panic(err) }
}

pub fn minus(a Value, b Value) Value {
	return sub(a, b) or { panic(err) }
}

pub fn times(a Value, b Value) Value {
	return mul(a, b) or { panic(err) }
}

pub fn over(a Value, b Value) Value {
	return truediv(a, b) or { panic(err) }
}

pub fn modulo(a Value, b Value) Value {
	return mod(a, b) or { panic(err) }
}

// either is `a or b` and both is `a and b`, for their value.
pub fn either(a Value, b Value) Value {
	return if truth(a) { a } else { b }
}

pub fn both(a Value, b Value) Value {
	return if truth(a) { b } else { a }
}

// elements is what `for x in v` visits.
pub fn elements(v Value) []Value {
	return iter(v) or { panic(err) }
}

// length is `len(v)`.
pub fn length(v Value) int {
	return len_(v) or { panic(err) }
}

// invoke is `v.name(args)`, for a method of a builtin type.
pub fn invoke(v Value, name string, args ...Value) Value {
	return call_method(v, name, args) or { panic(err) }
}

// has_text is the truth of text that may be None.
pub fn has_text(a ?string) bool {
	return (a or { '' }) != ''
}

// text_or is `a or b` where a may be None and b is text.
pub fn text_or(a ?string, b string) string {
	if found := a {
		if found != '' {
			return found
		}
	}
	return b
}

// first_text is `a or b` where both may be None.
pub fn first_text(a ?string, b ?string) ?string {
	if found := a {
		if found != '' {
			return found
		}
	}
	return b
}

// has is `item in v`.
pub fn has(v Value, item Value) bool {
	return contains(v, item) or { panic(err) }
}

// to_int, to_float, to_str and to_bool give a value of unknown type the plain type its
// context declares, with Python's TypeError when it is something else.
pub fn to_int(v Value) int {
	return int(as_int(v) or { panic(err) })
}

pub fn to_float(v Value) f64 {
	return as_float(v) or { panic(err) }
}

pub fn to_str(v Value) string {
	return as_str(v) or { panic(err) }
}

pub fn to_bool(v Value) bool {
	return as_bool(v) or { panic(err) }
}

// empty_list and empty_dict are `[]` and `{}` as runtime values.
pub fn empty_list() Value {
	return Value(new_list([]Value{}))
}

pub fn empty_dict() Value {
	return Value(new_dict())
}

// fail ends the program on an error no Python code caught: `SystemExit` leaves with its
// code and prints nothing, as the interpreter does; anything else is reported.
@[noreturn]
pub fn fail(err IError) {
	if e := caught(err, 'SystemExit') {
		code := if e.args.len > 0 { e.args[0] } else { none_ }
		if code is i64 {
			exit(int(code))
		}
		if code is int {
			exit(code)
		}
		if code is NoneType {
			exit(0)
		}
		eprintln(str(code))
		exit(1)
	}
	panic(err)
}

// unreachable marks a point generated code cannot reach, where V still asks for a value.
@[noreturn]
pub fn unreachable() {
	panic('py2v: reached code that the Python source cannot reach')
}
