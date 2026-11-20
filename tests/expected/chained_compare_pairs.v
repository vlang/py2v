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
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(50)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for py2v_range_item4 := py2v_range_start1; if py2v_range_step3 > 0 {
		py2v_range_item4 < py2v_range_stop2
	} else {
		py2v_range_item4 > py2v_range_stop2
	}; py2v_range_item4 = py2v_range_next1(py2v_range_item4, py2v_range_stop2, py2v_range_step3) {
		if 10 < n && n < 23 {
			n += 1
		}
	}
	println(n)
	mut counter := [0]
	py2v_cmp5 := bump(mut counter)
	if 0 < py2v_cmp5 && py2v_cmp5 < 5 {
		println('bumped once')
	}
	println(counter[0])
	ok := 1 <= xs.len && xs.len <= 3
	println(if ok { 'True' } else { 'False' })
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

fn main() {
	main_func()
}
