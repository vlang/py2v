module main

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
		if py2v_text_length1(w) > 3 {
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

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	show(map[string]int{
		'a': 1
		'b': 2
	}, 2, ['ab', 'abcd', 'zed'])
}
