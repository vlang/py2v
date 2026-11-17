module main

import os
import pyrt

fn main() {
	println('OK')
	pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.box(1)])))
}
