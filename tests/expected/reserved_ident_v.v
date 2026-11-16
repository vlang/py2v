module main

pub struct Holder {
pub mut:
	v int
}

fn (mut self Holder) init(v_ int) {
	self.v = v_
}

fn (mut self Holder) bump(v_ int) int {
	self.v = v_
	return self.v
}

pub fn py2v_new_holder(v_ int) Holder {
	mut py2v_instance := Holder{}
	py2v_instance.init(v_)
	return py2v_instance
}

fn local_use() int {
	mut v_ := py2v_new_holder(1)
	return v_.v + v_.bump(2)
}

fn param_use(v_ int) int {
	return v_ + 1
}

fn comprehension(rows [][]int) []string {
	mut py2v_comp1 := []string{}
	for row in rows {
		for v_ in row {
			py2v_comp1 << '${v_}'
		}
	}
	return py2v_comp1
}

fn spawn_(x int) int {
	return x * 2
}

fn exit_(x int) int {
	return x - 1
}

fn malloc_(n int) []int {
	return [0].repeat(n)
}

fn free_(p []int) int {
	return p.len
}

fn main() {
	println(spawn_(21))
	println(exit_(3))
	println(free_(malloc_(4)))
}
