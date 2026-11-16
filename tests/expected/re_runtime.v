module main

import regex
import time
import pyrt.re
import pyrt.pytime
import pyrt

const word = (re.compile('[a-z]+', 0) or { pyrt.fail(err) })

fn show_py(text string) ! {
	start := pytime.time_()
	m := re.search('(\\d+)-(\\d+)', text, 0)!.opt()
	if m != none {
		println('${pyrt.str(m.group(1)!)} ${pyrt.str(m.group(2)!)} ${pyrt.str(m.group(0)!)}')
	}
	println(pyrt.str(pyrt.box(word.findall(text))))
	println(re.sub('\\d', '#', text, 0, 0)!)
	println(word.sub('w', text, 0)!)
	parts := re.split('\\s+', text, 0, 0)!
	println(parts.len)
	found := word.match_(text)
	println(if found == none { 'True' } else { 'False' })
	println(if re.fullmatch('\\d+', '123', 0)!.opt() != none { 'True' } else { 'False' })
	elapsed := pytime.time_() - start
	println((if elapsed >= 0 { 'True' } else { 'False' }).str() + ' ' + (if pytime.monotonic() > 0 {
		'True'
	} else {
		'False'
	}).str())
}

fn show(text string) {
	show_py(text) or { pyrt.fail(err) }
}

fn main() {
	show('10-20 abc def 7')
}
