module main

fn count() {
	d := 2
	py2v_range_start1 := 0
	py2v_range_stop2 := 5
	py2v_range_step3 := d
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for r := py2v_range_start1; if py2v_range_step3 > 0 {
		r < py2v_range_stop2
	} else {
		r > py2v_range_stop2
	}; r = py2v_range_next1(r, py2v_range_stop2, py2v_range_step3) {
		println(r)
	}
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
	count()
}
