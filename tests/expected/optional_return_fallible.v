module main

import pyrt.json
import pyrt

fn load(text string) ?string {
	data := (json.loads(text) or { pyrt.fail(err) })
	if !pyrt.truth(data) {
		return none
	}
	return 'ok'
}

fn plain_py(text string) !string {
	data := json.loads(text)!
	return if pyrt.truth(data) { 'ok' } else { 'empty' }
}

fn plain(text string) string {
	return plain_py(text) or { pyrt.fail(err) }
}

fn main() {
	first := load('[1]')
	println((if first == none { 'True' } else { 'False' }).str() + ' ' + (if load('[]') == none {
		'True'
	} else {
		'False'
	}).str() + ' ' + (plain('[]')).str())
}
