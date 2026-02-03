@[translated]
module main

fn main_func() {
	mut i := 0
	for i < 5 {
		println(i.str())
		i += 1
	}
	mut j := 0
	for {
		if j >= 3 {
			break
		}

		println(j.str())
		j += 1
	}
	mut k := 0
	for k < 5 {
		k += 1
		if k == 3 {
			continue
		}

		println(k.str())
	}
}

fn main() {
	main_func()
}
