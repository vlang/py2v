module main

fn main() {
	println("True None 1e+16 ['é', None] '\\u96ea'")
	println("True [None] % '\\u96ea'")
	println('None True {done}')
	flag := true
	println((if flag { 'True' } else { 'False' }).str() + ' ' + ('${if flag {
		'True'
	} else {
		'False'
	}}').str() + ' ' + (if !flag { 'True' } else { 'False' }).str())
}
