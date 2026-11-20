module main

fn main_func() {
	amount := 2.9
	negative := -2.9
	println('${i64(amount)} ${i64(negative)}')
	println('[${i64(amount):5}][${i64(amount):05}][${i64(amount):-5}]')
	println('1 0')
	println('tag ${i64(amount)} ${amount:.6f} ${i64(true)}')
	println('4294967296')
	small := 2.9
	println('${i64(small)}')
	println('23')
}

fn main() {
	main_func()
}
