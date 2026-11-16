module main

pub struct Box {
pub mut:
	items []int
	names map[string]int
}

fn total(values []int) int {
	mut out := 0
	for v_ in values {
		out += v_
	}
	return out
}

fn longest(words []string) int {
	mut best := 0
	for w in words {
		if w.len > best {
			best = w.len
		}
	}
	return best
}

fn lookup(table map[string]int, key string) int {
	return table[key]
}

fn main() {
	nums := [int(3), 4, 5]
	words := ['a', 'abc', 'ab']
	table := {
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
