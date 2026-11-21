module main

type Bitboard = u64

const all = u64(18446744073709551615)

fn f(a u64) {
	b := u64(9223372036854775808)
	c := u64(9223372036854775808)
	println(if a == b { 'True' } else { 'False' })
	println(if a == c { 'True' } else { 'False' })
	println(b)
	println((a + b) & all)
}

fn main() {
	high := u64(9223372036854775808)
	f(high)
}
