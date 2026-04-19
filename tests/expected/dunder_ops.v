module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct Vector {
pub mut:
	x Any
	y Any
}

fn (mut self Vector) __init__(x int, y int) {
	self.x = x
	self.y = y
}

fn (self Vector) + (other Vector) Vector {
	return Vector{
		x: self.x + other.x
		y: self.y + other.y
	}
}

fn (self Vector) == (other Vector) bool {
	return self.x == other.x && self.y == other.y
}

fn (self Vector) str() string {
	return 'Vector(${self.x}, ${self.y})'
}

fn (self Vector) len() int {
	return 2
}

fn (self Vector) - () Vector {
	return Vector{
		x: -self.x
		y: -self.y
	}
}

fn main() {
	v1 := Vector{
		x: 1
		y: 2
	}
	v2 := Vector{
		x: 3
		y: 4
	}
	v3 := v1 + v2
	println(v3)
}
