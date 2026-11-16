module main

import crypto
import os
import pyrt.hashlib
import pyrt.subprocess
import pyrt.base64
import pyrt.uuid
import pyrt

// TODO(py2v): no V equivalent for import uuid
// Provide one in python_to_v_import (types.v) or port the module.

fn digest(text string) string {
	h := hashlib.sha256([]u8{})
	h.update(text.bytes())
	return h.hexdigest()
}

fn run_echo(word string) string {
	result := (subprocess.run(['echo', word], capture_output: true, text: true) or { pyrt.fail(err) })
	if result.returncode != 0 {
		return 'failed: ' + result.stderr_text()
	}
	return result.stdout_text().trim_space()
}

fn main_func() {
	println(digest('hello'))
	println(hashlib.md5([u8(0x61), 0x62, 0x63]).hexdigest())
	println(run_echo('hi'))
	println(base64.b64encode([u8(0x68), 0x65, 0x6c, 0x6c, 0x6f]).bytestr())
	println((uuid.uuid4() or { pyrt.fail(err) }).str().len)
}

fn main() {
	main_func()
}
