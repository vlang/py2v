@[translated]
module main

fn main_func() {
	for i in []int{len: 3, init: index} {
		for j in []int{len: 3, init: index} {
			println(((i * 3) + j).str())
		}
	}
	for i in []int{len: 5, init: index} {
		for j in []int{len: 5, init: index} {
			if j == 2 {
				break
			}

			println(((i * 10) + j).str())
		}
	}
}

fn main() {
	main_func()
}
