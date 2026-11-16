module main

fn show(name string, n int, ratio f64, ok bool) {
	println('hello ${name}')
	println('n ${n} ratio ${ratio}')
	println(name.str() + ' ' + (if ok { 'True' } else { 'False' }).str())
	println('a-b-${n}')
	println(('cost $').str() + ' ' + n.str())
	items := [1, 2]
	println('items ${items} ${items.len}')
}

fn main() {
	show('x', 3, 1.5, true)
}
