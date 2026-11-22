module main

fn squares(n int) []int {
	mut out := []int{}
	py2v_range_stop1 := int(n)
	for i in int(0) .. py2v_range_stop1 {
		out << py2v_integer_mul1(i, i, 'empty_container_inferred.py:4', 'multiplication')
	}
	return out
}

fn lengths(words []string) map[string]int {
	mut table := map[string]int{}
	for word in words {
		table[word] = word.len_utf8()
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
