module main

fn main_func() {
	d := {
		'k':      'K'
		'j':      'J'
		'my key': 'S'
		' k ':    'W'
	}
	xs := [10, 20]
	rows := [d]
	println('${d['k']} ${d['j']}')
	println('${d['k']}')
	println('${d['my key']}')
	println('${d[' k ']}')
	println('${xs[0]} ${xs[1]}')
	println('${rows[0]['k']}')
	index := 0
	if index < 0 {
		println('${xs[index]}')
	}
}

fn main() {
	main_func()
}
