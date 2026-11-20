module main

fn pick(items []int, begin int, end int, step int) []int {
	return py2v_slice_step1(items, begin, end, step)
}

fn py2v_slice_step1[T](values []T, lower ?int, upper ?int, step int) []T {
	if step == 0 {
		panic('ValueError: slice step cannot be zero')
	}
	n := values.len
	min_index := if step < 0 { -1 } else { 0 }
	max_index := if step < 0 { n - 1 } else { n }
	mut start := if step < 0 { max_index } else { min_index }
	mut stop := if step < 0 { min_index } else { max_index }
	if bound := lower {
		offset := if bound < 0 { bound + n } else { bound }
		start = if offset < min_index {
			min_index
		} else if offset > max_index {
			max_index
		} else {
			offset
		}
	}
	if bound := upper {
		offset := if bound < 0 { bound + n } else { bound }
		stop = if offset < min_index {
			min_index
		} else if offset > max_index {
			max_index
		} else {
			offset
		}
	}
	mut result := []T{}
	for index := start; if step < 0 { index > stop } else { index < stop }; index += step {
		result << values[index]
		if (step < 0 && step <= stop - index) || (step > 0 && step >= stop - index) {
			break
		}
	}
	return result
}

fn main() {
	items := [0, 1, 2, 3, 4, 5]
	println(pick(items, 100, -100, -2))
	println(pick(items, -100, 100, 4))
	println('${py2v_slice_step1(items, ?int(none), -1, -1)} ${py2v_slice_step1(items, ?int(none), ?int(none), -1)} ${py2v_slice_step1(items, 2, 2, 3)}')
}
