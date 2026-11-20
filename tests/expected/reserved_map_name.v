module main

fn choose(map_ bool) int {
	if map_ {
		return 1
	}
	return 0
}

fn main() {
	println(choose(true))
	println(choose(false))
}
