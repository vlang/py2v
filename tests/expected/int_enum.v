@[translated]
module main

const colors_red = auto()
const colors_green = auto()
const colors_blue = auto()

pub struct Colors {
}

const permissions_r = 1
const permissions_w = 2
const permissions_x = 16

pub struct Permissions {
}

fn show() {
	color_map := {
		colors_red:   'red'
		colors_green: 'green'
		colors_blue:  'blue'
	}
	a := colors_green
	if a == colors_green {
		println('green')
	} else {
		println('Not green')
	}
	b := permissions_r
	if b == permissions_r {
		println('R')
	} else {
		println('Not R')
	}
	assert color_map.len != 0
}

fn main() {
	show()
}
