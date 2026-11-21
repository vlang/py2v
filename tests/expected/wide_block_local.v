module main

type Bitboard = u64

const empty = u64(0)

const mask = u64(18446744073709551615)

pub struct Board {
pub mut:
	low  u64
	full u64
}

fn (mut self Board) init() {
	self.reset()
}

fn (mut self Board) reset() {
	self.low = empty
	self.full = mask
}

fn (self Board) choose(side int) u64 {
	mut bits := u64(0)
	if side == 0 {
		bits = self.low
	} else if side == 1 {
		bits = self.full
	} else {
		assert false
	}
	return bits >> 1
}

pub fn py2v_new_board() Board {
	mut py2v_instance := Board{}
	py2v_instance.init()
	return py2v_instance
}

fn main() {
	board := py2v_new_board()
	println(board.choose(0))
	println(board.choose(1))
}
