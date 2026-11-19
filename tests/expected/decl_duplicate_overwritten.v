module main

pub struct Sample {
}

fn (self Sample) value() int {
	return 2
}

fn (self Sample) alias() int {
	return 3
}

fn main() {
	sample := Sample{}
	println(sample.value())
	println(sample.alias())
}
