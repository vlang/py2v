/private/tmp/agent-run-502/ww-r2.1_qimwbh/tmp.8oTb6rwvxu/gen/tests/cases/hello-wuffs.py:49: py2v_unsupported_coroutine: test_parser requires an awaitable with unknown scheduling
module main

import os
import pyrt

// TODO(py2v): no V equivalent for import ctypes, py2many.result, pytest
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

pub struct Py2v_parser {
pub mut:
	val u32
}

fn test_parser(input Any, expected Any) {
	panic('py2v_unsupported_coroutine: test_parser requires an awaitable with unknown scheduling')
}

fn main() {
	(pyrt.untranslated_import('pytest.main') or { pyrt.fail(err) })
	println('OK')
}
