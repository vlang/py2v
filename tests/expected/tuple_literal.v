module main

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

fn mixed() (int, string) {
	return 1, 'hello'
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
