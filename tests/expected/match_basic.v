@[translated]
module main

type Any = bool | int | i64 | f64 | string | []u8

fn classify(status int) string {
	match status {
		200 {
			return 'OK'
		}
		404 {
			return 'Not Found'
		}
		500 {
			return 'Server Error'
		}
		else {
			return 'Unknown'
		}
	}
}

fn direction(cmd string) string {
	match cmd {
		'north', 'south' {
			return 'vertical'
		}
		'east', 'west' {
			return 'horizontal'
		}
		else {
			return 'unknown'
		}
	}
}

fn check_singleton(val Any) Any {
	match val {
		true {
			return 'yes'
		}
		false {
			return 'no'
		}
		none {
			return 'nothing'
		}
		else {
			return 'other'
		}
	}
}

fn main() {
	println(classify(200))
	println(classify(404))
	println(classify(999))
	println(direction('north'))
	println(direction('east'))
}
