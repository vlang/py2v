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
		result = py2v_integer_add1(result, 10, 'exception_lowering.py:7', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}
