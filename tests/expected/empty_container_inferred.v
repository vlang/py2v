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
		out << py2v_integer_mul1(i, i, 'empty_container_inferred.py:4', 'multiplication')
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
			total = py2v_integer_add1(total, cell, 'empty_container_inferred.py:29', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	words := ['aa', 'b']
	println(squares(4))
	println(lengths(words))
	println(names())
	println(nested())
}
