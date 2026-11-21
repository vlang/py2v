module main

import pyrt

type Any = pyrt.Value

fn fill(status map[string]Any, record Any, text string) {
	pyrt.set_index(status['tasks'], pyrt.box('total'), pyrt.box(3))
	pyrt.set_index(status['tasks'], pyrt.box('names'), pyrt.box([pyrt.box('a'), pyrt.box('b')]))
	pyrt.set_index(record, pyrt.box('count'), pyrt.plus(pyrt.item_at(record, pyrt.box('count')), pyrt.box(1)))
	pyrt.set_index(record, pyrt.box('seen'), pyrt.box(true))
	println((pyrt.str(pyrt.item_at(status['tasks'], pyrt.box('total')))).str() + ' ' + (pyrt.str(pyrt.item_at(record, pyrt.box('count')))).str() + ' ' + (pyrt.str(pyrt.item_at(record, pyrt.box('seen')))).str())
	println('${py2v_slice_step1(text.runes(), ?int(none), 3, 1).string()} ${py2v_slice_step1(text.runes(), 1, ?int(none), 1).string()} ${py2v_slice_step1(text.runes(), 1, 3, 1).string()}')
	head := pyrt.slice_of(pyrt.item_at(record, pyrt.box('title')), pyrt.none_, pyrt.box(5))
	println('${pyrt.str(head)} ${pyrt.length(head)}')
	println(pyrt.str(pyrt.item_at(pyrt.item_at(status['tasks'], pyrt.box('names')), pyrt.box(0))))
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
	fill(map[string]Any{
		'tasks': pyrt.box(map[string]Any{
			'total': pyrt.box(0)
		})
	}, pyrt.box(map[string]Any{
		'count': pyrt.box(1)
		'title': pyrt.box('hello world')
	}), 'abcdef')
}
