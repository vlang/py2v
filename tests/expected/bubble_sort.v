module main

fn bubble_sort(mut seq []int) []int {
	l := seq.len
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(l)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for py2v_range_item4 := py2v_range_start1; if py2v_range_step3 > 0 {
		py2v_range_item4 < py2v_range_stop2
	} else {
		py2v_range_item4 > py2v_range_stop2
	}; py2v_range_item4 = py2v_range_next1(py2v_range_item4, py2v_range_stop2, py2v_range_step3) {
		py2v_range_start5 := int(1)
		py2v_range_stop6 := int(l)
		py2v_range_step7 := int(1)
		if py2v_range_step7 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for n := py2v_range_start5; if py2v_range_step7 > 0 {
			n < py2v_range_stop6
		} else {
			n > py2v_range_stop6
		}; n = py2v_range_next1(n, py2v_range_stop6, py2v_range_step7) {
			if seq[n] < seq[n - 1] {
				seq[n - 1], seq[n] = seq[n], seq[n - 1]
			}
		}
	}
	return seq
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
	mut unsorted := [14, 11, 19, 5, 16, 10, 19, 12, 5, 12]
	expected := [5, 5, 10, 11, 12, 12, 14, 16, 19, 19]
	assert bubble_sort(mut unsorted) == expected
	println('OK')
}
