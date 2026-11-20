module main

fn pick(mode int) fn (int) int {
	if mode == 1 {
		calculate := fn (value int) int {
			return value + 2
		}
		return calculate
	} else if mode == 2 {
		calculate := fn (value int) int {
			return value * 2
		}
		return calculate
	} else {
		calculate := fn (value int) int {
			return value - 2
		}
		return calculate
	}
}

fn main() {
	first := pick(1)
	second := pick(2)
	third := pick(3)
	println('${first(5)} ${second(5)} ${third(5)}')
}
