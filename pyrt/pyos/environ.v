module pyos

import os
import pyrt

// The process environment as `os.environ` shows it: reads and writes go to the process.

// putenv is `os.environ[name] = value`.
pub fn putenv(name string, value string) {
	os.setenv(name, value, true)
}

// unsetenv is `os.environ.pop(name, None)` used as a statement.
pub fn unsetenv(name string) {
	os.unsetenv(name)
}

// environ_item is `os.environ[name]`, with Python's KeyError for a name that is not set.
pub fn environ_item(name string) string {
	return os.getenv_opt(name) or { missing(name) }
}

// environ_delete is `del os.environ[name]`.
pub fn environ_delete(name string) {
	if _ := os.getenv_opt(name) {
		os.unsetenv(name)
		return
	}
	missing(name)
}

// environ_has is `name in os.environ`.
pub fn environ_has(name string) bool {
	return os.getenv_opt(name) != none
}

// environ_setdefault is `os.environ.setdefault(name, value)`.
pub fn environ_setdefault(name string, value string) string {
	if found := os.getenv_opt(name) {
		return found
	}
	os.setenv(name, value, true)
	return value
}

@[noreturn]
fn missing(name string) {
	pyrt.fail(pyrt.key_error(pyrt.Value(name)))
}
