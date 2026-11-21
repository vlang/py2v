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
		if py2v_text_length1(w) > best {
			best = py2v_text_length1(w)
		}
	}
	return best
}

fn lookup(table map[string]int, key string) int {
	return table[key]
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
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
