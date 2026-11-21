module main

type Square = int

pub struct Move {
pub mut:
	source    int
	target    int
	promotion ?int = none
}

fn (self Move) to_bool() bool {
	return !!(self.source != 0 || self.target != 0 || (self.promotion != none && self.promotion != 0))
}

fn (self Move) label() string {
	return if self.to_bool() { 'present' } else { 'empty' }
}

fn main() {
	println(Move{
		source: 0
		target: 0
	}.label())
	println(Move{
		source: 1
		target: 0
	}.label())
	println(Move{
		source:    0
		target:    0
		promotion: 3
	}.label())
}
