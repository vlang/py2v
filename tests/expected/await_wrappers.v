module main

fn nested() int {
	return 7
}

fn show() {
	a := nested()
	b := nested()
	assert a == 7
	assert b == 7
}

fn main() {
	// import asyncio: use V goroutines and channels
	show()
}
