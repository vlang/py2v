module main

pub struct Token {
pub mut:
	type_ string = 'word'
	name  string = ''
}

fn (self Token) kind() string {
	return self.type_
}

fn main_func() {
	t := Token{}
	println(t.kind())
}

fn main() {
	main_func()
}
