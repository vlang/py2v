module main

fn main_func() {
	for i in []int{len: 3, init: index} {
		print(i)
	}
	println('')
	for i in []int{len: 3, init: index} {
		print(i.str() + ' ')
	}
	println('')
	println('a-b-c')
	println('ab')
	print('${1}, ${2}, ${3}' + '!\n')
	print('no newline')
	println('')
	print(' ')
	println('after space')
	name := 'x'
	n := 4
	println('${name}=${n}')
	print('${name} ${n}' + ';\n')
	println(("it's").str() + "'" + ('quoted').str())
	println((2.5).str() + '|' + (if true { 'True' } else { 'False' }).str())
	println('plain default')
	print('tab' + '\t')
	println('done')
}

fn main() {
	main_func()
}
