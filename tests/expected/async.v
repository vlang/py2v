module main

type Any = bool | int | i64 | f64 | string | []u8

fn async_gen(ch chan Any) {
	defer { ch.close() }
	for i in []int{len: 3, init: index} {
		ch <- i
	}
}

fn show_async() {
	// async for lowered to goroutine + channel
	__ch1 := chan Any{}
	go async_gen(__ch1)
	for val in __ch1 {
		println(val)
	}
}

fn show() {
	show_async()
}

fn main() {
	// import asyncio: use V goroutines and channels
	show()
}
