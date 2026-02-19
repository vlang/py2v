@[translated]
module main

import log

fn process() {
	log.info('starting')
	log.debug('x=42')
	log.warn('low memory')
	log.warn('also a warning')
	log.error('failed')
	log.error('shutdown')
	log.error('caught error')
}

fn main() {
	process()
}
