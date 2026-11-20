module main

import os

pub struct Choice {
}

fn (self Choice) label() string {
	return 'native'
}

pub struct Gate {
}

fn (self Gate) label() string {
	return 'runtime'
}

fn main() {
	println(Choice{}.label())
	println(Gate{}.label())
}
