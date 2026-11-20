module main

const block_ = 2

const limit = 3

fn walk(n int) int {
	mut total := 0
	py2v_range_start1 := 0
	py2v_range_stop2 := n
	py2v_range_step3 := block_
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for start := py2v_range_start1; if py2v_range_step3 > 0 {
		start < py2v_range_stop2
	} else {
		start > py2v_range_stop2
	}; start = py2v_range_next1(start, py2v_range_stop2, py2v_range_step3) {
		total += start
	}
	py2v_range_start4 := 0
	py2v_range_stop5 := n
	py2v_range_step6 := limit
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for start := py2v_range_start4; if py2v_range_step6 > 0 {
		start < py2v_range_stop5
	} else {
		start > py2v_range_stop5
	}; start = py2v_range_next1(start, py2v_range_stop5, py2v_range_step6) {
		total += start
	}
	return total
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
	println(walk(7))
}
