module main

import regex

fn main() {
	pattern := regex.regex_opt('\\d+') or { panic(err) }
	text := 'hello 42 world'
	m := (regex.regex_opt('hello') or { panic(err) }).match_string(text)
	s := (regex.regex_opt('\\d+') or { panic(err) }).find(text)
	matches := (regex.regex_opt('\\d+') or { panic(err) }).find_all_str(text)
	result := (regex.regex_opt('\\d+') or { panic(err) }).replace(text, 'NUM')
	parts := (regex.regex_opt('\\s+') or { panic(err) }).split(text)
	fm := (regex.regex_opt('hello \\d+ world') or { panic(err) }).match_string(text)
	println(result)
}
