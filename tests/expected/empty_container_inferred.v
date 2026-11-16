module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn squares(n int) []int {
	mut out := []int{}
	for i in []int{len: n, init: index} {
		out << i * i
	}
	return out
}

fn lengths(words []string) map[string]int {
	mut table := map[string]int{}
	for word in words {
		table[word] = word.len
	}
	return table
}

fn names() []string {
	mut found := []string{}
	found << 'a'
	found << ['b']
	return found
}

fn nested() int {
	mut rows := [][]int{}
	rows << [1, 2]
	rows << [3]
	mut total := 0
	for row in rows {
		for cell in row {
			total += cell
		}
	}
	return total
}

fn main() {
	words := ['aa', 'b']
	println(squares(4))
	println(lengths(words))
	println(names())
	println(nested())
}
