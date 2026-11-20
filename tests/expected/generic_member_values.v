module main

pub struct NamedCount[I, C] {
pub mut:
	label I
	count C
}

fn (mut self NamedCount[I, C]) init(label I, count C) {
	self.label = label
	self.count = count
}

fn (self NamedCount[I, C]) read_count() C {
	return self.count
}

pub fn py2v_new_named_count[I, C](label I, count C) NamedCount[I, C] {
	mut py2v_instance := NamedCount[I, C]{}
	py2v_instance.init(label, count)
	return py2v_instance
}

fn make(label string, count int) NamedCount[string, int] {
	return py2v_new_named_count(label, count)
}

fn main() {
	first := make('first', 101)
	second := make('second', -990)
	println('${second.read_count()} ${first.label} ${first.read_count()} ${second.label}')
}
