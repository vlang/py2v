module main

fn after_loop(n int) int {
	mut x := 0
	for {
		x = n + 1
		break
	}
	return x
}

fn from_branches(n int) string {
	mut label := ''
	if n > 0 {
		label = 'pos'
	} else if n == 0 {
		label = 'zero'
	} else {
		label = 'neg'
	}
	return label
}

fn collected(words []string) int {
	mut hits := []string{}
	mut total := 0
	for w in words {
		if w.starts_with('a') {
			hits = [w]
			total = w.len_utf8()
		} else {
			hits = []
			total = 0
		}
		if total > 2 {
			return hits.len + total
		}
	}
	return -1
}

fn only_inside(n int) int {
	if n > 3 {
		local := py2v_integer_mul1(n, 2, 'block_locals_declared.py:33', 'multiplication')
		return local
	}
	return n
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

fn main() {
	println('${after_loop(1)} ${from_branches(2)} ${from_branches(0)} ${from_branches(-1)}')
	println((collected(['b', 'abc'])).str() + ' ' + (only_inside(5)).str() + ' ' + (only_inside(1)).str())
}
