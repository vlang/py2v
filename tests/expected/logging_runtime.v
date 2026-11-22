module main

import log
import os
import pyrt.logging
import pyrt

const logger = logging.get_logger('__main__')

fn work(n int, name string) int {
	logger.debug('starting %s', pyrt.box(name))
	logger.info('processing %d items for %s', pyrt.box(n), pyrt.box(name))
	if n > 2 {
		logger.warning('large batch: %d', pyrt.box(n))
	}
	logger.error_('done %s with ratio %.2f', pyrt.box(name), pyrt.box(f64(n) / 3))
	return py2v_integer_mul1(n, 2, 'logging_runtime.py:13', 'multiplication')
}

fn main_func_py() ! {
	logging.basic_config(
		level:  logging.info_level
		format: '%(levelname)s %(name)s %(message)s'
		stream: 'stdout'
	)!
	println(work(3, 'alpha'))
	logger.info('plain message')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
