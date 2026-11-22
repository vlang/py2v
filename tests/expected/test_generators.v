module main

fn simple_generator(ch chan int) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
	ch <- 3
}

fn generator_with_type(ch chan int) {
	defer { ch.close() }
	mut x := 0
	for x < 5 {
		ch <- x
		x = py2v_integer_add1(x, 1, 'test_generators.py:16', 'addition')
	}
}

fn generator_with_args(a int, b int, ch chan i64) {
	defer { ch.close() }
	py2v_range_start1 := int(a)
	py2v_range_stop2 := int(b)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		ch <- py2v_integer_mul1(i, 2, 'test_generators.py:22', 'multiplication')
	}
}

fn generator_with_yield_from(ch chan int) {
	defer { ch.close() }
	inner := fn (ch chan int) {
		defer { ch.close() }
		ch <- 1
		ch <- 2
	}
	py2v_gen4 := inner()
	// yield from py2v_gen4
	for {
		val := <-py2v_gen4 or { break }
		ch <- val
	}
	ch <- 3
}

fn generator_with_condition(ch chan int) {
	defer { ch.close() }
	py2v_range_start5 := int(0)
	py2v_range_stop6 := int(10)
	py2v_range_step7 := int(1)
	if py2v_range_step7 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start5; if py2v_range_step7 > 0 {
		i < py2v_range_stop6
	} else {
		i > py2v_range_stop6
	}; i = py2v_range_next1(i, py2v_range_stop6, py2v_range_step7) {
		if i % 2 == 0 {
			ch <- i
		}
	}
}

fn test_generator_calls() {
	gen1 := simple_generator()
	gen2 := generator_with_args(1, 5)
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

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}
