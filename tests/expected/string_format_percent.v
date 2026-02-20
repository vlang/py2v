@[translated]
module main

fn main_func() {
	name := 'world'
	age := 25
	pi := 3.1415900000000003
	println('hello ${name}')
	println('name=${name} age=${age}')
	println('pi is ${pi:.2f}')
	println('count: ${age}')
	println('padded: ${age:05}')
	println('hex: ${255:x}')
	println('${name} is ${age} years old and likes ${pi:.1f}')
	println('score: ${95}%')
	println('default float: ${pi:.6f}')
	println('truncated: ${pi:.0f}')
	println('left-pad: ${age:-5}')
	println(((10 % 3)).str())
	println(((17 % 5)).str())
}

fn main() {
	main_func()
}
