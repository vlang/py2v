module main

fn param_collision_escape(n int) int {
	mut n_ := 0
	mut py2v_bound1 := false
	py2v_range_stop2 := int(n)
	for n_1 in int(0) .. py2v_range_stop2 {
		n_ = n_1
		py2v_bound1 = true
		// pass
	}
	if !py2v_bound1 { py2v_unbound_local1('n') }
	return n_
}

fn nested_escape() int {
	mut x := 0
	for x_ in [1, 2] {
		x = x_
		for x_1 in [10, 20] {
			x = x_1
			// pass
		}
	}
	return x
}

fn breakless_for_else_return() int {
	mut x := 0
	for x_ in [1, 2, 3] {
		x = x_
		// pass
	}
	return x
}

fn breakless_for_else_scoped() int {
	for _ in int(0) .. int(2) {
		// pass
	}
	{
		mut msg := ''
		if true {
			msg = 'ok'
		}
		println(msg)
	}
	mut total := 0
	for msg in [10, 20] {
		mut py2v_iter_value3 := msg
		py2v_iter_value3 = py2v_integer_add1(py2v_iter_value3, 1, 'loop_escaping_bindings.py:32', 'addition')
		total = py2v_integer_add1(total, py2v_iter_value3, 'loop_escaping_bindings.py:33', 'addition')
	}
	return total
}

fn vararg_early_return(flag bool, args ...int) int {
	if flag {
		for args_ in [1, 2] {
			// pass
		}
		return 0
	}
	return args.len
}

fn sequential_retype() string {
	for x in [1, 2] {
		// pass
	}
	mut x := ''
	for x_ in ['a', 'b'] {
		x = x_
		// pass
	}
	return x
}

fn unbound_shadow_comp(xs []int, flag bool) []int {
	mut x := 0
	mut py2v_bound4 := false
	for x_ in xs {
		x = x_
		py2v_bound4 = true
		// pass
	}
	if xs.len > 0 {
		if !py2v_bound4 { py2v_unbound_local1('x') }
		return [x]
	}
	return if flag { [10, 20].map(it + 1) } else { [] }
}

@[noreturn]
fn py2v_unbound_local1(var_name string) {
	flush_stdout()
	eprintln("UnboundLocalError: cannot access local variable '${var_name}' where it is not associated with a value")
	exit(1)
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
	println(param_collision_escape(3))
	println(nested_escape())
	println(breakless_for_else_return())
	println(breakless_for_else_scoped())
	println('${vararg_early_return(false, 10, 20)} ${vararg_early_return(true, 10, 20)}')
	println(sequential_retype())
	println(unbound_shadow_comp([], true))
	println(unbound_shadow_comp([7], true))
}
