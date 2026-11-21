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

fn py2v_entry1() ! {
	first := load('[1]')
	println((if first == none { 'True' } else { 'False' }).str() + ' ' + (if load('[]') == none {
		'True'
	} else {
		'False'
	}).str() + ' ' + (plain_py('[]')!).str())
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
