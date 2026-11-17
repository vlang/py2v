module main

import pyrt

fn text(label string, value ?string) ?string {
	println(label)
	return value
}

fn main() {
	if pyrt.has_text(text('none', none)) {
		println('bad-none')
	}
	if !pyrt.has_text(text('empty', '')) {
		println('empty')
	}
	println(if pyrt.has_text(text('set', 'yes')) { 1 } else { 0 })
	for pyrt.has_text(text('loop', none)) {
		println('bad-loop')
	}
	println(if !(pyrt.has_text(text('first', '')) || pyrt.has_text(text('second', 'ok'))) {
		'True'
	} else {
		'False'
	})
}
