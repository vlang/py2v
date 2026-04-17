@[translated]
module main

import strings

fn main_func() {
	println(if '42'.len < 5 { strings.repeat(`0`, 5 - '42'.len) + '42' } else { '42' })
	println(if 'hello'.len < 3 { strings.repeat(`0`, 3 - 'hello'.len) + 'hello' } else { 'hello' })
	println(if 'hi'.len < 6 { 'hi' + strings.repeat(' '[0], 6 - 'hi'.len) } else { 'hi' })
	println(if 'hi'.len < 6 { strings.repeat(' '[0], 6 - 'hi'.len) + 'hi' } else { 'hi' })
	println(if 'hi'.len < 6 { 'hi' + strings.repeat('*'[0], 6 - 'hi'.len) } else { 'hi' })
	println(if 'hi'.len < 6 { strings.repeat('-'[0], 6 - 'hi'.len) + 'hi' } else { 'hi' })
	println(if 'hi'.len < 6 {
		lpad := (6 - 'hi'.len) / 2
		strings.repeat(' '[0], lpad) + 'hi' + strings.repeat(' '[0], 6 - 'hi'.len - lpad)
	} else {
		'hi'
	})
	println(if 'hi'.len < 7 {
		lpad := (7 - 'hi'.len) / 2
		strings.repeat('-'[0], lpad) + 'hi' + strings.repeat('-'[0], 7 - 'hi'.len - lpad)
	} else {
		'hi'
	})
}

fn main() {
	main_func()
}
