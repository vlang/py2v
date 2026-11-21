module main

type Bitboard = u64

fn masked(a u64, count int) {
	println((a << 8) & u64(18446744073709551615))
	println((a << 5) & u64(i64(9223372036854775807)))
	println(py2v_shift_left_u641(a, count) & u64(18446744073709551615))
	println((a + (u64(1) << 62)) & u64(18446744073709551615))
}

fn py2v_shift_left_u641[T](value u64, count T) u64 {
	if count < 0 { panic('ValueError: negative shift count') }
	if count >= 64 { return 0 }
	return value << int(count)
}

fn main() {
	high := u64(9223372036854775808)
	masked(high, 12)
}
