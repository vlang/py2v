@[translated]
module main

import os

fn main() {
	for {
		name := os.input("What's your name? (type <quit> to quit)")
		if name == '<quit>' {
			break
		}

		println((('Hello ' + name) + '!'))
	}
}
