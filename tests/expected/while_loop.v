module main

fn main_func() {
	mut i := 0
	for i < 5 {
		println(i)
		i = py2v_integer_add1(i, 1, 'while_loop.py:6', 'addition')
	}
	mut j := 0
	for {
		if j >= 3 {
			break
		}
		println(j)
		j = py2v_integer_add1(j, 1, 'while_loop.py:14', 'addition')
	}
	mut k := 0
	for k < 5 {
		k = py2v_integer_add1(k, 1, 'while_loop.py:19', 'addition')
		if k == 3 {
			continue
		}
		println(k)
	}
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
	main_func()
}
