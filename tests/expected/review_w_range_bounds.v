module main

fn start() int {
	println('start')
	return 2
}

fn end() int {
	println('end')
	return 4
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
	py2v_range_start1 := int(start())
	py2v_range_stop2 := int(end())
	for i in py2v_range_start1 .. py2v_range_stop2 {
		println('call ${i}')
	}
	mut n := 4
	py2v_range_stop3 := int(n)
	for i in int(0) .. py2v_range_stop3 {
		println('snapshot ${i}')
		n = 0
	}
	py2v_range_start4 := int(5)
	py2v_range_stop5 := int(-1)
	py2v_range_step6 := int(-2)
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start4; if py2v_range_step6 > 0 {
		i < py2v_range_stop5
	} else {
		i > py2v_range_stop5
	}; i = py2v_range_next1(i, py2v_range_stop5, py2v_range_step6) {
		println('negative ${i}')
	}
	py2v_range_stop7 := int(1)
	for i in int(3) .. py2v_range_stop7 {
		println('wrong ${i}')
	}
	println('empty else')
}
