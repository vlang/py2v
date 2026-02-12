@[translated]
module main

__global (
	code_0 = 0
	code_1 = 1
	code_a = 'a'
	code_b = 'b'
	l_b    = [code_a]
	l_c    = {
		code_b: code_0
	}
)
fn main() {
	assert 'a' in l_b
	println('OK')
}
