module main

pub struct Piece {
pub mut:
	code int
}

// @classmethod
fn Piece.null() Piece {
	return Piece{
		code: 0
	}
}

// @classmethod
fn Piece.from_code(code int) Piece {
	if code == 0 {
		return Piece.null()
	}
	return Piece{
		code: code
	}
}

fn main() {
	println(Piece.from_code(0).code)
	println(Piece.from_code(7).code)
}
