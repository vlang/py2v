module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct Holder {
pub mut:
	v Any
}

fn (mut self Holder) init(v_ int) {
	self.v = v_
}

fn (mut self Holder) bump(v_ int) int {
	self.v = v_
	return self.v
}

fn local_use() int {
	v_ := Holder{
		v: 1
	}
	return v_.v + v_.bump(2)
}

fn param_use(v_ int) int {
	return v_ + 1
}

fn comprehension(rows [][]int) []string {
	return rows.map('${v_}')
}

fn spawn_(x int) int {
	return x * 2
}

fn exit_(x int) int {
	return x - 1
}

fn malloc_(n int) list {
	return [0].repeat(n)
}

fn free_(p list) int {
	return p.len
}

fn main() {
	println(spawn_(21))
	println(exit_(3))
	println(free_(malloc_(4)))
}
