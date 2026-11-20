module main

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
