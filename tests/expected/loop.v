@[translated]
module main

fn for_with_break() {
	for i in []int{len: 4, init: index} {
		if i == 2 {
			break
		}

		println(i)
	}
}

fn for_with_continue() {
	for i in []int{len: 4, init: index} {
		if i == 2 {
			continue
		}

		println(i)
	}
}

fn for_with_else() {
	has_break := false
	for i in []int{len: 4, init: index} {
		println(i)
	}
	if has_break != true {
		println('OK')
	}
}

fn while_with_break() {
	mut i := 0
	for {
		if i == 2 {
			break
		}

		println(i)
		i += 1
	}
}

fn while_with_continue() {
	mut i := 0
	for i < 5 {
		i += 1
		if i == 2 {
			continue
		}

		println(i)
	}
}

fn main() {
	for_with_break()
	for_with_continue()
	for_with_else()
	while_with_break()
	while_with_continue()
}
