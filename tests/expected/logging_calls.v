module main

import log
import pyrt.logging
import pyrt

fn process() {
	(logging.basic_config() or { pyrt.fail(err) })
	logging.info('starting')
	logging.debug('x=42')
	logging.warning('low memory')
	logging.warn('also a warning')
	logging.error_('failed')
	logging.critical('shutdown')
	logging.exception('caught error')
}

fn main() {
	process()
}
