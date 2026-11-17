module main

fn collect(enabled bool) []int {
	if enabled {
		values := [1, 2]
	}
	return values.map(it)
}

fn augmented(enabled bool) []int {
	mut values := []int{}
	if enabled {
		values = [1, 2]
	} else {
		values << [3]
	}
	return values.map(it)
}

fn main() {
	println(collect(true))
}
