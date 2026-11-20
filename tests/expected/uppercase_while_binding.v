module main

fn repeat() {
	mut s := true
	for s {
		for i in [1] {
			println(i)
		}
		s = false
	}
}

fn main() {
	repeat()
}
