module main

fn squares(n int) []int {
	mut out := []int{}
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(n)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		out << i * i
	}
	return out
}

fn lengths(words []string) map[string]int {
	mut table := map[string]int{}
	for word in words {
		table[word] = py2v_text_length1(word)
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

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	words := ['aa', 'b']
	println(squares(4))
	println(lengths(words))
	println(names())
	println(nested())
}
