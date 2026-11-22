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
	return py2v_integer_mul1(x, 2, 'reserved_ident_v.py:23', 'multiplication')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	println(spawn_(21))
	println(exit_(3))
	println(free_(malloc_(4)))
}
