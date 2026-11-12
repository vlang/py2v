module main

fn main() {
	xs := [int(1), 2, 3]
	empty := []int{}
	println(...xs + ' ' + (0).str())
	println(('start').str() + ' ' + ...xs + ' ' + ('end').str())
	println(...empty + ' ' + (0).str())
	println(...xs + ' ' + ...empty)
}
