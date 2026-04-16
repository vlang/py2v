@[translated]
module main

pub struct Point {
pub mut:
	x     f64
	y     f64
	label string = 'origin'
}

pub struct Circle {
pub mut:
	center &Point
	radius f64 = 1
}

fn show() {
	p := Point{
		x: 1.5
		y: 2.5
	}
	println(p.x)
	println(p.label)
	c := Circle{
		center: p
		radius: 3
	}
	println(c.radius)
}

fn main() {
	show()
}
