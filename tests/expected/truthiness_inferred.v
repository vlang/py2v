module main

fn describe(name string, items []int, count int, ratio f64) string {
	mut parts := []string{}
	if name != '' {
		parts << 'named'
	}
	if !(items.len > 0) {
		parts << 'no items'
	}
	if count != 0 && items.len > 0 {
		parts << 'counted'
	}
	if !(ratio != 0.0) || !(name != '') {
		parts << 'zero or anonymous'
	}
	mut left := count
	for left != 0 {
		left = py2v_integer_sub1(left, 1, 'truthiness_inferred.py:13', 'subtraction')
	}
	label := if items.len > 0 { 'some' } else { 'none' }
	parts << label
	return parts.join(',')
}

fn tally(words []string) map[string]int {
	mut seen := map[string]int{}
	for word in words {
		if word != '' {
			seen[word] = py2v_text_length1(word)
		}
	}
	if !(seen.len > 0) {
		seen['empty'] = 0
	}
	return seen
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	empty := []int{}
	full := [int(1)]
	some_words := ['a', '', 'bb']
	no_words := []string{}
	println(describe('x', full, 2, 0.5))
	println(describe('', empty, 0, 0.0))
	println(tally(some_words))
	println(tally(no_words))
}
