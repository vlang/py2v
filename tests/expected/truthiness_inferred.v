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
		left -= 1
	}
	label := if items.len > 0 { 'some' } else { 'none' }
	parts << label
	return parts.join(',')
}

fn tally(words []string) map[string]int {
	mut seen := map[string]int{}
	for word in words {
		if word != '' {
			seen[word] = word.len_utf8()
		}
	}
	if !(seen.len > 0) {
		seen['empty'] = 0
	}
	return seen
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
