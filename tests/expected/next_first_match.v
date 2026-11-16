module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn show(ranks map[string]int, rank int, words []string) {
	mut name := ?string(none)
	for k, v_ in ranks {
		if v_ == rank {
			name = k
			break
		}
	}
	if name == none {
		println('no name')
	} else {
		println(name)
	}
	mut long_word := 'none'
	for w in words {
		if w.len > 3 {
			long_word = w
			break
		}
	}
	println(long_word)
	mut py2v_first1 := 'nothing'
	for w in words {
		if w.starts_with('z') {
			py2v_first1 = w.to_upper()
			break
		}
	}
	println(py2v_first1)
	mut missing := ?string(none)
	for k, v_ in ranks {
		if v_ > 99 {
			missing = k
			break
		}
	}
	println(if missing == none { 'True' } else { 'False' })
}

fn main() {
	show(map[string]int{
		'a': 1
		'b': 2
	}, 2, ['ab', 'abcd', 'zed'])
}
