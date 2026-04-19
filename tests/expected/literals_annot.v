module main

import math

fn main() {
	num := 42
	pi := 3.14
	s := 'hello'
	flag := true
	b := [byte(0x61), 0x62, 0x63]
	c := 1 + math.complex(0.0, 2.0)
	println(num + ' ' + pi + ' ' + s + ' ' + if flag { 'True' } else { 'False' } + ' ' + b + ' ' + c)
}
