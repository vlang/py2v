module main

import pyrt

fn weighted_py(first int, middle int, last int) !int {
	if middle == 0 {
		return pyrt.raise('ValueError', 'middle cannot be zero')
	}
	return first * 100 + middle * 10 + last
}

fn weighted(first int, middle int, last int) int {
	return weighted_py(first, middle, last) or { pyrt.fail(err) }
}

fn score_py(values []int) !int {
	start := values[0]
	return weighted_py(-2, start, 3)!
}

fn score(values []int) int {
	return score_py(values) or { pyrt.fail(err) }
}

fn main() {
	println(score([10]))
	println(weighted(3, 2, 1))
}
