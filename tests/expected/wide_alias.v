module main

import math.bits as py2v_math_bits1

type Bitboard = u64

const mask = u64(18446744073709551615)

const file_h = u64(9259542123273814144)

const plain_mask = u64(18446744073709551615)

type OtherWidth = u64

const other_mask = u64(9223372036854775808)

type SignedWidth = int

const signed_negative = -1

const signed_small = 1 << 30

pub struct Board {
pub mut:
	bits u64
}

fn (mut self Board) init(bits u64) {
	self.bits = bits
}

fn (self Board) low() u64 {
	return self.bits & (u64(0) - self.bits)
}

pub fn py2v_new_board(bits u64) Board {
	mut py2v_instance := Board{}
	py2v_instance.init(bits)
	return py2v_instance
}

fn full() u64 {
	return mask
}

fn negative() int {
	return signed_negative
}

fn show(bits u64, count int) {
	println(full())
	println(plain_mask)
	println(other_mask)
	println(negative())
	println(signed_small & 0)
	println(bits & (u64(0) - bits))
	println(bits & (bits - u64(1)))
	println((bits + bits) & mask)
	println((bits * u64(3)) & mask)
	println(~bits & mask)
	println(py2v_shift_left_u641(file_h, count) & mask)
	println(py2v_shift_right_u641(bits, count))
	println(py2v_shift_left_u641(bits, 64) & mask)
	println(py2v_shift_right_u641(bits, 64))
	println(bits | u64(0))
	println(bits ^ mask)
	println(py2v_math_bits1.len_64(bits))
	println(py2v_math_bits1.ones_count_64(bits))
	println(if py2v_cmp_u64_int1(bits, i64(-1)) > 0 { 'True' } else { 'False' })
	println(if py2v_cmp_u64_int1(bits, i64(count)) > 0 { 'True' } else { 'False' })
	println(if py2v_cmp_int_u641(i64(count), bits) < 0 { 'True' } else { 'False' })
	println(if py2v_cmp_u64_int1(bits, i64(0)) != 0 { 'True' } else { 'False' })
}

fn py2v_shift_left_u641[T](value u64, count T) u64 {
	if count < 0 { panic('ValueError: negative shift count') }
	if count >= 64 { return 0 }
	return value << int(count)
}

fn py2v_shift_right_u641[T](value u64, count T) u64 {
	if count < 0 { panic('ValueError: negative shift count') }
	if count >= 64 { return 0 }
	return value >> int(count)
}

fn py2v_cmp_u64_int1(a u64, b i64) int {
	if b < 0 || a > u64(b) { return 1 }
	if a < u64(b) { return -1 }
	return 0
}

fn py2v_cmp_int_u641(b i64, a u64) int {
	if b < 0 || a > u64(b) { return -1 }
	if a < u64(b) { return 1 }
	return 0
}

fn main() {
	show(mask, 7)
	board := py2v_new_board(mask)
	println(board.low())
}
