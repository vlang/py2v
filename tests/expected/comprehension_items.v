module main

import arrays
import math

fn show(small map[string]int, big map[string]int, rank int) {
	mut py2v_comp1 := []bool{}
	for k, v_ in small {
		py2v_comp1 << big[k] >= v_
	}
	println(if py2v_comp1.all(it) { 'True' } else { 'False' })
	mut py2v_comp2 := []string{}
	for k, v_ in small {
		if v_ == rank {
			py2v_comp2 << k
		}
	}
	println(py2v_comp2)
	mut py2v_comp3 := map[string]int{}
	for k, v_ in small {
		py2v_comp3[k] = py2v_integer_mul1(v_, 2, 'comprehension_items.py:7', 'multiplication')
	}
	println(py2v_comp3)
	println(py2v_integer_inferred_sum1(small.values().map(it), 0, 'comprehension_items.py:8'))
	println(big.keys().filter((it !in small)).map(it).sorted())
	mut py2v_comp4 := []bool{}
	for _, v_ in big {
		py2v_comp4 << v_ > 1
	}
	println(if py2v_comp4.any(it) { 'True' } else { 'False' })
	mut names := []string{}
	for k, v_ in big {
		if v_ > 0 && k != 'z' {
			names << k + v_.str()
		}
	}
	println('${names.len} ${names}')
	mut grid := []int{}
	for x in [1, 2] {
		for y in [10, 20] {
			grid << py2v_integer_mul1(x, y, 'comprehension_items.py:13', 'multiplication')
		}
	}
	println(grid)
	mut py2v_comp5 := []int{}
	for py2v_zipi1, n in [1, 2, 3] {
		w := [4, 5, 6][py2v_zipi1]
		py2v_comp5 << py2v_integer_mul1(n, w, 'comprehension_items.py:15', 'multiplication')
	}
	total := py2v_integer_sum1(py2v_comp5, 0, 'comprehension_items.py:15')
	println(total)
	mut py2v_comp6 := []string{}
	for k, v_ in small {
		py2v_comp6 << '${k}=${v_}'
	}
	println(py2v_comp6.join(', '))
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

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn py2v_integer_sum1[T](items []T, start int, site string) int {
	$if (T is $int && T !is u64) || T is bool {
		mut total := start
		for item in items { total = py2v_integer_add1(total, int(item), site, 'sum') }
		return total
	} $else {
		$compile_error('py2v_unsupported_integer_sum: expected native integer elements')
	}
}

fn py2v_integer_inferred_sum1[T](items []T, start int, site string) T {
	$if T is u64 {
		$compile_error('py2v_unsupported_wide_integer: sum may exceed u64')
	} $else $if T is $int {
		value := py2v_integer_sum1(items, start, site)
		if value < int(math.minof[T]()) || value > int(math.maxof[T]()) {
			py2v_integer_overflow1(site, 'integer narrowing')
		}
		return T(value)
	} $else {
		$if T is $float {
			if start != 0 { return arrays.fold(items, T(start), |acc, item| acc + item) }
		}
		return arrays.sum(items) or { 0 }
	}
}

fn main() {
	show(map[string]int{
		'a': 1
		'b': 2
	}, map[string]int{
		'a': 1
		'b': 3
		'c': 0
	}, 2)
}
