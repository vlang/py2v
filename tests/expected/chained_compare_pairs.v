module main

fn in_unit(v_ f64) bool {
	return 0 <= v_ && v_ < 1
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
	for _ in []int{len: 50, init: index} {
		if 10 < n && n < 23 {
			n += 1
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

fn main() {
	main_func()
}
