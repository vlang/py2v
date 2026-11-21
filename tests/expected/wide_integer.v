module main

fn accepts_literal(value f64) bool {
	return value == -i64(100000000000)
}

fn main() {
	exact := i64(9007199254740993)
	signed_max := i64(9223372036854775807)
	signed_min := i64(-9223372036854775808)
	high_bit := u64(9223372036854775808)
	mask := u64(18446744073709551615)
	println(exact)
	println(signed_max)
	println(signed_min)
	println(high_bit)
	println(mask)
	println(mask & u64(exact))
	println(high_bit | u64(i64(9007199254740993)))
	println(mask ^ high_bit)
	println(~high_bit & mask)
	println((mask << 8) & mask)
	println((mask >> 8) & mask)
	println((u64(exact) << 63) & mask)
	println(if accepts_literal(f64(-i64(100000000000))) { 'True' } else { 'False' })
}
