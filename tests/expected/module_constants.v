module main

const seconds_per_minute_ = 60

const max_size = 3

const lower_ = 2

const names = ['a', 'b', 'c']

const units = {
	'k': 1000
	'm': 1000000
}

const double = max_size * 2

fn total() int {
	return seconds_per_minute_ * max_size + lower_ + double
}

fn pick(i int) string {
	return names[i]
}

fn scale(unit string) int {
	return units[unit]
}

fn main() {
	mut counter := 0
	counter = counter + 1
	println(total())
	println(pick(1))
	println(scale('m'))
	println(counter)
}
