module main

fn for_with_break() {
	for i in int(0) .. int(4) {
		if i == 2 {
			break
		}
		println(i)
	}
}

fn for_with_continue() {
	for i in int(0) .. int(4) {
		if i == 2 {
			continue
		}
		println(i)
	}
}

fn for_with_else() {
	has_break := false
	for i in int(0) .. int(4) {
		println(i)
	}
	if has_break != true {
		println('OK')
	}
}

fn while_with_break() {
	mut i := 0
	for {
		if i == 2 {
			break
		}
		println(i)
		i = py2v_integer_add1(i, 1, 'loop.py:28', 'addition')
	}
}

fn while_with_continue() {
	mut i := 0
	for i < 5 {
		i = py2v_integer_add1(i, 1, 'loop.py:34', 'addition')
		if i == 2 {
			continue
		}
		println(i)
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
	for_with_break()
	for_with_continue()
	for_with_else()
	while_with_break()
	while_with_continue()
}
