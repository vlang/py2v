module main

import pyrt
import math

fn render_py(items []int, divisor int) !string {
	if divisor == 0 {
		return pyrt.raise('ValueError', 'zero divisor')
	}
	mut result := ''
	for value in items {
		result += (math.modulo_floored[int](value, divisor)).str()
	}
	return result
}

fn render(items []int, divisor int) string {
	return render_py(items, divisor) or { pyrt.fail(err) }
}

fn main() {
	println(render([1, 2, -3, 4], 2))
	println(render([1, 2, -3, 4], -3))
	println(-7)
	println(math.modulo_floored[int](15, 8))
	println(1)
}
