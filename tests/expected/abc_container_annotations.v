module main

pub struct Box {
pub mut:
	items []int
	names map[string]int
}

fn total(values []int) int {
	mut out := 0
	for v_ in values {
		out = py2v_integer_add1(out, v_, 'abc_container_annotations.py:14', 'addition')
	}
	return out
}

fn longest(words []string) int {
	mut best := 0
	for w in words {
		if w.len_utf8() > best {
			best = w.len_utf8()
		}
	}
	return best
}

fn lookup(table map[string]int, key string) int {
	return table[key]
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
	nums := [int(3), 4, 5]
	words := ['a', 'abc', 'ab']
	table := map[string]int{
		'x': 7
	}
	println(total(nums))
	println(longest(words))
	println(lookup(table, 'x'))
	box := Box{
		items: nums
		names: table
	}
	println(total(box.items) + lookup(box.names, 'x'))
}
