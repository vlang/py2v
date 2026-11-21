module main

fn after_loop(n int) int {
	mut x := 0
	for {
		x = n + 1
		break
	}
	return x
}

fn from_branches(n int) string {
	mut label := ''
	if n > 0 {
		label = 'pos'
	} else if n == 0 {
		label = 'zero'
	} else {
		label = 'neg'
	}
	return label
}

fn collected(words []string) int {
	mut hits := []string{}
	mut total := 0
	for w in words {
		if w.starts_with('a') {
			hits = [w]
			total = py2v_text_length1(w)
		} else {
			hits = []
			total = 0
		}
		if total > 2 {
			return hits.len + total
		}
	}
	return -1
}

fn only_inside(n int) int {
	if n > 3 {
		local := n * 2
		return local
	}
	return n
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	println('${after_loop(1)} ${from_branches(2)} ${from_branches(0)} ${from_branches(-1)}')
	println((collected(['b', 'abc'])).str() + ' ' + (only_inside(5)).str() + ' ' + (only_inside(1)).str())
}
