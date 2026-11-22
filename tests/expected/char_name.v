module main

fn shout(char_ string) string {
	return char_.to_upper() + '!'
}

fn count_vowels(text string) int {
	mut total := 0
	for char_ in text.split('') {
		if 'aeiou'.contains(char_) {
			total = py2v_integer_add1(total, 1, 'char_name.py:9', 'addition')
		}
	}
	return total
}

fn main_func() {
	println(shout('a'))
	println(count_vowels('education'))
	char_ := 'z'
	println(char_)
	letters := 'xyz'.split('').map(it)
	println(letters)
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	main_func()
}
