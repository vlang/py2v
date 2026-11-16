module pyrt

// str is what Python's `str(e)` gives for an exception, so that `'${e}'` and `e.str()` in
// translated handlers print the message and not the fields of the V struct.
pub fn (e PyError) str() string {
	return e.msg()
}

// exception_of makes an exception of a class of the translated program: its name, the
// classes it derives from down to the builtin ones (each brings the builtin's own bases),
// and its arguments.
pub fn exception_of(class_name string, bases []string, args []Value) PyError {
	mut all := bases.clone()
	for base in bases {
		for inherited in exception_bases(base) {
			if inherited !in all {
				all << inherited
			}
		}
	}
	return PyError{
		class_name: class_name
		bases:      all
		args:       args.clone()
	}
}

// opt is the value as V's option, for code that tests it against `none`.
pub fn (m Maybe[T]) opt() ?T {
	if m.has {
		return m.value
	}
	return none
}
