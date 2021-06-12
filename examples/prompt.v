import os

for {
	mut name := os.input("What's your name? (type <quit> to quit)")
	if name == '<quit>' {
		break
	}
	println('Hello ' + name + '!')
}
