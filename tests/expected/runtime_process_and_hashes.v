module main

import crypto
import os
import pyrt.hashlib
import pyrt.subprocess
import pyrt
import pyrt.base64
import pyrt.uuid

// TODO(py2v): no V equivalent for import uuid
// Provide one in python_to_v_import (types.v) or port the module.

fn digest(text string) string {
	h := hashlib.sha256([]u8{})
	h.update(text.bytes())
	return h.hexdigest()
}

fn run_echo_py(word string) !string {
	result := subprocess.run(['echo', word], capture_output: true, text: true)!
	if result.returncode != 0 {
		return 'failed: ' + result.stderr_text()
	}
	return result.stdout_text().trim_space()
}

fn run_echo(word string) string {
	return run_echo_py(word) or { pyrt.fail(err) }
}

fn main_func_py() ! {
	println(digest('hello'))
	println(hashlib.md5([u8(0x61), 0x62, 0x63]).hexdigest())
	println(run_echo_py('hi')!)
	println(base64.b64encode([u8(0x68), 0x65, 0x6c, 0x6c, 0x6f]).bytestr())
	println(py2v_text_length1((uuid.uuid4()!).str()))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	main_func()
}
