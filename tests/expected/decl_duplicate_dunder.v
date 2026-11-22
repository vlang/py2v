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
	return py2v_integer_add1(value, 1, 'decl_duplicate_dunder.py:9', 'addition')
}

fn (self Sample) py2v_dunder_getitem(value int) int {
	return py2v_integer_add1(value, 2, 'decl_duplicate_dunder.py:12', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
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
