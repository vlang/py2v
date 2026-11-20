module main

fn probe(label string) string {
	println(label)
	return label
}

fn main() {
	println(7)
	println(9)
	println(if -1 != 0 { -1 } else { 3 })
	println(if -0.0 != 0.0 { -0.0 } else { 2.5 })
	println(if -0.0 != 0.0 { 9.0 } else { -0.0 })
	println(if 2.0 != 0.0 { 2.0 } else { 3.5 })
	println('fallback')
	println(if true { 'True' } else { 'False' })
	println(if false { 'True' } else { 'False' })
	println(probe('run-or'))
	println('None')
	println(if !false { 'True' } else { 'False' })
	if false {
		println('bad-none')
	} else {
		println('none')
	}
	if false {
		println('bad-list')
	} else {
		println('empty-list')
	}
	for false {
		println('bad-tuple')
	}
}
