module main

import pyrt

// TODO(py2v): no V mapping for KeyError.init
// Each site below is stubbed with a zero value.

// TODO(py2v): 5 except handler(s) need a V Result equivalent:
//   else clause (1 stmt)
//   except (1 stmt)
//   except KeyError | TypeError (1 stmt)
//   except OSError (1 stmt)
//   except ValueError as e (1 stmt)

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

pub struct PortageException {
pub mut:
	value Any
}

fn (mut self PortageException) init(value Any) {
	self.value = value
}

pub fn py2v_new_portage_exception(value Any) PortageException {
	mut py2v_instance := PortageException{}
	py2v_instance.init(value)
	return py2v_instance
}

// PortageKeyError - Mixes a builtin exception into a project hierarchy. V has no KeyError, so
// that base is dropped and reported; the project base becomes an embedded
// initialiser call.
pub struct PortageKeyError {
	PortageException
}

fn (mut self PortageKeyError) init(value Any) {
	_ = Any(0)
	self.PortageException.init(value)
}

pub fn py2v_new_portage_key_error(value Any) PortageKeyError {
	mut py2v_instance := PortageKeyError{}
	py2v_instance.init(value)
	return py2v_instance
}

fn try_finally_only() int {
	mut result := 0
	defer {
		result += 10
	}
	result = 1
	return result
}

fn handler_is_reported() int {
	mut value := 0
	value = risky()
	// except handlers are not translated: see the TODO(py2v) note above
	//   except ValueError as e: 1 statement(s) need an `or { ... }` equivalent
	//   except KeyError | TypeError: 1 statement(s) need an `or { ... }` equivalent
	return value
}

fn bare_handler() int {
	mut value := 0
	value = risky()
	// except handlers are not translated: see the TODO(py2v) note above
	//   except: 1 statement(s) need an `or { ... }` equivalent
	return value
}

fn else_is_dropped() int {
	mut value := 0
	value = 1
	// else: runs only when the try body raises, which no V construct here does
	// except handlers are not translated: see the TODO(py2v) note above
	//   except OSError: 1 statement(s) need an `or { ... }` equivalent
	return value
}

fn risky() int {
	return 1
}
