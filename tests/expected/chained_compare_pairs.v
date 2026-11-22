module main

fn in_unit(v_ f64) bool {
	return 0.0 <= v_ && v_ < 1.0
}

fn between(lo int, x int, hi int) bool {
	return lo < x && x <= hi
}

fn ascending(a int, b int, c int, d int) bool {
	return a < b && b < c && c < d
}

fn bump(mut counter []int) int {
	counter[0] += 1
	return counter[0]
}

fn main_func() {
	println(if in_unit(0.5) { 'True' } else { 'False' })
	println(if in_unit(1.5) { 'True' } else { 'False' })
	println(if in_unit(-0.5) { 'True' } else { 'False' })
	println(if between(1, 5, 10) { 'True' } else { 'False' })
	println(if between(1, 11, 10) { 'True' } else { 'False' })
	println(if between(1, 1, 10) { 'True' } else { 'False' })
	println(if ascending(1, 2, 3, 4) { 'True' } else { 'False' })
	println(if ascending(1, 2, 3, 3) { 'True' } else { 'False' })
	println(if ascending(1, 3, 2, 4) { 'True' } else { 'False' })
	xs := [3, 7, 9]
	i := 1
	if 0 <= i && i < xs.len {
		println('index ok')
	}
	if 5 < xs[i] && xs[i] < 7 {
		println('not printed')
	}
	if 5 < xs[i] && xs[i] == 7 {
		println('seven')
	}
	mut n := 20
	for _ in int(0) .. int(50) {
		if 10 < n && n < 23 {
			n = py2v_integer_add1(n, 1, 'chained_compare_pairs.py:39', 'addition')
		}
	}
	println(n)
	mut counter := [0]
	py2v_cmp1 := bump(mut counter)
	if 0 < py2v_cmp1 && py2v_cmp1 < 5 {
		println('bumped once')
	}
	println(counter[0])
	ok := 1 <= xs.len && xs.len <= 3
	println(if ok { 'True' } else { 'False' })
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
