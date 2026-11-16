module main

import math

fn digits(number int, base int) int {
	return int(math.log_n(number, base)) + 1
}

fn main() {
	println(math.round_sig(math.log_n(8, 2), 6))
	println(math.round_sig(math.log_n(1000, 10), 6))
	println('${math.round_sig(math.log(math.e), 6)} ${math.round_sig(math.log(1), 6)}')
	println(digits(1000, 4))
}
