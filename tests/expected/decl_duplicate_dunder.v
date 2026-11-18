module main

pub struct Sample {
}

fn (self Sample) contains(value int) bool {
	return value == 1
}

fn (self Sample) py2v_dunder_contains(value int) bool {
	return value == 2
}

fn (self Sample) index(value int) int {
	return value + 1
}

fn (self Sample) py2v_dunder_getitem(value int) int {
	return value + 2
}

fn (self Sample) repr() string {
	return 'ordinary'
}

fn (self Sample) py2v_dunder_repr() string {
	return 'dunder'
}

fn (self Sample) to_int() int {
	return 3
}

fn (self Sample) py2v_dunder_int() int {
	return 4
}

fn main() {
	sample := Sample{}
	println(if sample.contains(1) { 'True' } else { 'False' })
	println(if sample.py2v_dunder_contains(2) { 'True' } else { 'False' })
	println(sample.index(1))
	println(sample.py2v_dunder_getitem(1))
	println(sample.repr())
	println(sample.py2v_dunder_repr())
	println(sample.to_int())
	println(sample.py2v_dunder_int())
}
