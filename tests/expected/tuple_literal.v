module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

const direction_north = 'north'
const direction_south = 'south'
const direction_east = 'east'
const direction_west = 'west'

enum Speed {
	speed_1 = 1
	speed_2 = 2
	speed_3 = 3
	speed_4 = 4
	speed_5 = 5
}

fn coords() (int, int) {
	return 1, 2
}

fn rgb() (int, int, int) {
	return 255, 0, 128
}

// NOTE: Tuple[int, string] — define a struct with named fields
fn mixed() []Any {
	return [1, 'hello']
}

fn variable_len() []int {
	return [1, 2, 3]
}

fn move(direction string, speed int) {
	println('${direction} ${speed}')
}

fn main() {
	move('north', 3)
}
