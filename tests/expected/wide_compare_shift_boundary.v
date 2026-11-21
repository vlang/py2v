module main

type Bitboard = u64

fn main() {
	high := u64(9223372036854775808)
	println(if high == (u64(1) << 63) { 'True' } else { 'False' })
	println(if high <= ((u64(1) << 62) << 1) { 'True' } else { 'False' })
	println(if (u64(1) << 63) >= high { 'True' } else { 'False' })
	println(if high != (u64(1) << 63) { 'True' } else { 'False' })
}
