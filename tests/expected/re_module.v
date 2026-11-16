module main

import regex
import pyrt.re
import pyrt

fn main() {
	pattern := (re.compile('\\d+', 0) or { pyrt.fail(err) })
	text := 'hello 42 world'
	m := (re.match_('hello', text, 0) or { pyrt.fail(err) }).opt()
	s := (re.search('\\d+', text, 0) or { pyrt.fail(err) }).opt()
	matches := (re.findall('\\d+', text, 0) or { pyrt.fail(err) })
	result := (re.sub('\\d+', 'NUM', text, 0, 0) or { pyrt.fail(err) })
	parts := (re.split('\\s+', text, 0, 0) or { pyrt.fail(err) })
	fm := (re.fullmatch('hello \\d+ world', text, 0) or { pyrt.fail(err) }).opt()
	println(result)
}
