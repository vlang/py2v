@[translated]

module main

pub struct P_struct {
}

fn main() {
	mut p := P_struct{}
	p.name = 'Bob'
	person := {
		'name': 'Alice'
	}
	data := {
		'a': {
		'b': 'B'
	}
	}
	lst := [10, 20]
	println('Hi ${p.name}')
	println('Hello ${person['name']}')
	println('Nested: ${data['a']['b']}')
	println('First: ${lst[0]}')
}
