module main

import strconv

type Bitboard = u64

const high = u64(9223372036854775808)

const mask = u64(18446744073709551615)

fn show(value u64) {
	println(value.str())
	println(('0b' + strconv.format_uint(value, 2)))
	println(('0x' + value.hex()))
	println(value.hex())
}

fn main() {
	show(high)
	show(mask)
}
