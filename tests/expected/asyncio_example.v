@[translated]
module main

fn nested() int {
	return 42
}

fn async_main() {
	assert nested() == 42
	println('OK')
}

fn main() {
	asyncio.run(async_main())
}
