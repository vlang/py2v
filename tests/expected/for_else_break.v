module main

fn main_func() {
	mut py2v_broke1 := false
	for x in [1, 2, 3] {
		if x == 2 {
			println('found ${x}')
			py2v_broke1 = true
			break
		}
	}
	if !py2v_broke1 {
		println('missing')
	}
	mut py2v_broke2 := false
	for x in [1, 2, 3] {
		if x == 5 {
			py2v_broke2 = true
			break
		}
	}
	if !py2v_broke2 {
		println('no 5')
	}
	mut py2v_broke4 := false
	for i in int(0) .. int(4) {
		mut py2v_broke3 := false
		for j in int(0) .. int(4) {
			if j > i {
				py2v_broke3 = true
				break
			}
		}
		if !py2v_broke3 {
			println('inner done ${i}')
		}
		if i == 2 {
			py2v_broke4 = true
			break
		}
	}
	if !py2v_broke4 {
		println('outer done')
	}
	mut n := 5
	mut py2v_broke5 := false
	for n > 0 {
		n -= 1
		if n == 2 {
			println('stopped at ${n}')
			py2v_broke5 = true
			break
		}
	}
	if !py2v_broke5 {
		println('ran out')
	}
	mut k := 0
	for k < 3 {
		k = py2v_integer_add1(k, 1, 'for_else_break.py:37', 'addition')
	}
	println('counted ${k}')
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
