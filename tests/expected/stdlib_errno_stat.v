module main

import os
import log

fn is_dir(mode int) bool {
	return (mode & 0o170000) == 0o040000
}

fn is_regular(mode int) bool {
	return (mode & 0o170000) == 0o100000
}

fn is_link(mode int) bool {
	return (mode & 0o170000) == 0o120000
}

fn is_fifo(mode int) bool {
	return (mode & 0o170000) == 0o010000
}

fn setuid(mode int) bool {
	return (mode & 0o4000) != 0
}

fn permissions(mode int) int {
	return mode & 0o7777
}

fn missing() bool {
	return 2 == 2
}

fn stale() int {
	return 116
}

fn denied() int {
	return 13
}

fn term_handler() bool {
	return os.Signal.term == os.Signal.term
}

fn on_term() {
	os.signal_opt(os.Signal.term, fn (_ os.Signal) { on_term() }) or { os.SignalHandler(unsafe { nil }) }
}

fn flag(msg string) {
	log.warn('deprecated')
	log.warn(msg)
}
