module main

fn take(text string, stride int) []string {
	return py2v_slice_step1(text.split(','), ?int(none), ?int(none), stride)
}

fn main_func() {
	println(take('alpha,beta,gamma,delta', -2).join('/'))
	texts := ['red,green,blue', 'a,b,c,d,e']
	println(py2v_slice_step1(texts[0].split(','), ?int(none), ?int(none), -1).join('/'))
	println(py2v_slice_step1(texts[1].split(','), 4, 0, -2).join('/'))
	parts := take(texts[1], 1)
	println(py2v_slice_step1(parts, 1, 4, 2).join('/'))
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
	main_func()
}
