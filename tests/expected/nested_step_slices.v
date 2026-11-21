module main

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
	a := [0, 1, 2, 3, 4, 5, 6, 7, 8]
	println(py2v_slice_step1(py2v_slice_step1(a, 1, 7, 2), ?int(none), ?int(none), -1))
	println(py2v_slice_step1(py2v_slice_step1(a, 1, 8, 2), ?int(none), ?int(none), 2))
	println(py2v_slice_step1(py2v_slice_step1('abcdef'.runes(), 1, 6, 2).string().runes(), ?int(none), ?int(none), -1).string())
	println(py2v_slice_step1(py2v_slice_step1('🙂ab'.runes(), ?int(none), ?int(none), 2).string().runes(), ?int(none), ?int(none), -1).string())
}
