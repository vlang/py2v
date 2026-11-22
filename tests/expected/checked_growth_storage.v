module main

pub struct Counter {
pub mut:
	total int
}

fn (mut self Counter) init() {
	self.total = 1
}

fn (mut self Counter) grow() {
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(5)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		self.total = py2v_integer_add1(self.total, self.total, 'checked_growth_storage.py:7', 'addition')
	}
}

pub fn py2v_new_counter() Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init()
	return py2v_instance
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
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
	mut item := py2v_new_counter()
	item.grow()
	println(item.total)
	mut values := [1]
	py2v_range_start4 := int(0)
	py2v_range_stop5 := int(5)
	py2v_range_step6 := int(1)
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start4; if py2v_range_step6 > 0 {
		i < py2v_range_stop5
	} else {
		i > py2v_range_stop5
	}; i = py2v_range_next1(i, py2v_range_stop5, py2v_range_step6) {
		values[0] = py2v_integer_add1(values[0], values[0], 'checked_growth_storage.py:16', 'addition')
	}
	println(values[0])
}
