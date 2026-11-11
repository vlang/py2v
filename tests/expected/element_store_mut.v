module main

pub struct Point {
pub mut:
	x int
}

fn (mut self Point) init(x int) {
	self.x = x
}

pub struct Box {
pub mut:
	items []int
}

fn (mut self Box) init(items []int) {
	self.items = items
}

fn (mut self Box) put() {
	self.items[0] = 5
}

fn (mut self Box) bump() {
	self.items[1] += 5
}

fn main_func() {
	mut a := [int(1), 2]
	a[0] += 1
	println(a)
	mut counts := {
		'x': 1
	}
	counts['x'] += 1
	println(counts['x'])
	mut grid := [[1, 2], [3, 4]]
	grid[0][1] = 5
	grid[1][0] *= 3
	println(grid)
	mut b := Box{
		items: [1, 2]
	}
	b.put()
	b.bump()
	println(b.items)
	mut points := [Point{
		x: 1
	}, Point{
		x: 2
	}]
	points[0].x = 7
	println(points[0].x)
	mut lists := {
		'a': [1, 2]
	}
	lists['a'][1] = 9
	println(lists['a'])
}

fn main() {
	main_func()
}
