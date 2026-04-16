@[translated]
module main

fn main() {
	code_0 := 0
	code_1 := 1
	l_a := [code_0, code_1]
	code_a := 'a'
	code_b := 'b'
	l_b := [code_a, code_b]
	for i in l_a {
		println(i)
	}
	for j in l_b {
		println(j)
	}
	if 'a' in ['a', 'b'] {
		println('OK')
	}
}
