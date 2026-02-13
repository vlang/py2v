@[translated]
module main

const colors_red = 'red'
const colors_green = 'green'
const colors_blue = 'blue'

pub struct Colors {
}

fn show() {
	color_map := {
		colors_red:   '1'
		colors_green: '2'
		colors_blue:  '3'
	}
	a := colors_green
	if a == colors_green {
		println('green')
	} else {
		println('Not green')
	}
	println((color_map.len).str())
}

fn main() {
	show()
}
