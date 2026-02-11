@[translated]
module main

pub struct Colors {
}

pub struct Permissions {
}

fn show() {
	color_map := {
		Colors.RED:   'red'
		Colors.GREEN: 'green'
		Colors.BLUE:  'blue'
	}
	a := Colors.GREEN
	if a == Colors.GREEN {
		println('green')
	} else {
		println('Not green')
	}
	b := Permissions.R
	if b == Permissions.R {
		println('R')
	} else {
		println('Not R')
	}
	assert color_map.len != 0
}

fn main() {
	show()
}
