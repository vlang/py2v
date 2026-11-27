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

fn generator_with_args(ch chan int, a int, b int) {
	defer { ch.close() }
	py2v_range_start1 := int(a)
	py2v_range_stop2 := int(b)
	for i in py2v_range_start1 .. py2v_range_stop2 {
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
	py2v_gen3 := inner()
	// yield from py2v_gen3
	for {
		val := <-py2v_gen3 or { break }
		ch <- val
	}
	ch <- 3
}

fn generator_with_condition(ch chan int) {
	defer { ch.close() }
	for i in int(0) .. int(10) {
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

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}
