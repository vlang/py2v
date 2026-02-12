@[translated]
module main

pub struct Colors {
}

fn show() {
	color_map := {
		Colors.RED:   '1'
		Colors.GREEN: '2'
		Colors.BLUE:  '3'
	}
	a := Colors.GREEN
	if a == Colors.GREEN {
		println('green')
	} else {
		println('Not green')
	}
	println((color_map.len).str())
}

fn main() {
	show()
}
