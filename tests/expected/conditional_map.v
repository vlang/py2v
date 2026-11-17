module main

fn choose(flag bool, key string) map[string]int {
	return if flag {
		({
			key: 3
		})
	} else {
		({
			key: 7
		})
	}
}

fn main() {
	println(choose(true, 'x'))
	println(choose(false, 'x'))
}
