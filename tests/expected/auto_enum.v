module main

pub enum Termination {
	checkmate = 1
	stalemate = 2
}

pub fn (member Termination) str() string {
	return match member {
		.checkmate { 'Termination.CHECKMATE' }
		.stalemate { 'Termination.STALEMATE' }
	}
}

fn main() {
	println(Termination.checkmate)
	println(Termination.stalemate)
	println(if Termination.checkmate == Termination.stalemate { 'True' } else { 'False' })
}
