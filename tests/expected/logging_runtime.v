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
	return n * 2
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

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
