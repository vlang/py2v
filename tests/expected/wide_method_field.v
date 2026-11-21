module main

import math.bits as py2v_math_bits1

type Bitboard = u64

const empty = u64(0)

const mask = u64(18446744073709551615)

pub struct Board {
pub mut:
	occupied u64
}

fn (mut self Board) init() {
	self.reset()
}

fn (mut self Board) reset() {
	self.occupied = empty | mask
}

fn (mut self Board) flip() {
	self.occupied = self.occupied ^ mask
}

fn (self Board) population() int {
	return py2v_math_bits1.ones_count_64(self.occupied)
}

pub fn py2v_new_board() Board {
	mut py2v_instance := Board{}
	py2v_instance.init()
	return py2v_instance
}

fn main() {
	mut board := py2v_new_board()
	println(board.population())
	board.flip()
	println(board.population())
}
