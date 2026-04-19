module main

type Any = bool | int | i64 | f64 | string | []u8

fn describe(point Any) Any {
	if point.len == 2 && point[0] == 0 && point[1] == 0 {
		return 'origin'
	} else if point.len == 2 && point[1] == 0 {
		x := point[0]
		return 'on x-axis at ${x}'
	} else if point.len == 2 && point[0] == 0 {
		y := point[1]
		return 'on y-axis at ${y}'
	} else if point.len == 2 {
		x := point[0]
		y := point[1]
		return 'at (${x}, ${y})'
	} else {
		return 'not a point'
	}
}

fn parse_command(command map[string]Any) string {
	if 'action' in command && command['action'] == 'quit' {
		return 'quitting'
	} else if 'action' in command && command['action'] == 'move' && 'direction' in command {
		direction := command['direction']
		return 'moving ${direction}'
	} else {
		return 'unknown command'
	}
}

fn check_guard(n int) string {
	if n < 0 {
		x := n
		return 'negative'
	} else if n == 0 {
		return 'zero'
	} else if n > 100 {
		x := n
		return 'large'
	} else {
		return 'normal'
	}
}

fn main() {
	println(describe([0, 0]))
	println(describe([3, 0]))
	println(describe([1, 2]))
	println(parse_command({
		'action': 'quit'
	}))
	println(check_guard(-5))
	println(check_guard(0))
	println(check_guard(200))
	println(check_guard(42))
}
