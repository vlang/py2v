module main

import pyrt

pub struct Packet[X, Y] {
}

fn packet() ?Packet[pyrt.NoneType, int] {
	return none
}

fn main() {
	println(if packet() == none { 'True' } else { 'False' })
}
