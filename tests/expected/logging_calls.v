module main

import log
import pyrt.logging
import pyrt

fn process_py() ! {
	logging.basic_config()!
	logging.info('starting')
	logging.debug('x=42')
	logging.warning('low memory')
	logging.warn('also a warning')
	logging.error_('failed')
	logging.critical('shutdown')
	logging.exception('caught error')
}

fn process() {
	process_py() or { pyrt.fail(err) }
}

fn main() {
	process()
}
