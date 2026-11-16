module pyos

import os
import pyrt

// These process-backed, non-result helpers
// expose Python os.environ mutation and missing-key behavior to generated code.
pub fn putenv(name string, value string) {
    os.setenv(name, value, true)
}

pub fn unsetenv(name string) {
    os.unsetenv(name)
}

pub fn environ_item(name string) string {
    return os.getenv_opt(name) or { missing(name) }
}

pub fn environ_delete(name string) {
    if _ := os.getenv_opt(name) {
        os.unsetenv(name)
        return
    }
    missing(name)
}

pub fn environ_has(name string) bool {
    return os.getenv_opt(name) != none
}

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
