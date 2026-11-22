module main

import math

fn key(value int) int {
	println(value)
	return math.modulo_floored[int](value, 2)
}

fn main_func() {
	mut values := [3, 1, 4, 2]
	println((fn (items []int) []int {
		keys := items.map(key(it))
		mut order := []int{len: items.len, init: index}
		order.sort_with_compare(fn [keys] (lhs &int, rhs &int) int {
			a := keys[*lhs]
			b := keys[*rhs]
			if a < b { return -1 }
			if b < a { return 1 }
			return if *lhs < *rhs {
				-1
			} else if *lhs > *rhs {
				1
			} else {
				0
			}
		})
		return order.map(items[it])
	})(values))
	(fn (mut items []int) {
		keys := items.map(key(it))
		mut order := []int{len: items.len, init: index}
		order.sort_with_compare(fn [keys] (lhs &int, rhs &int) int {
			a := keys[*rhs]
			b := keys[*lhs]
			if a < b { return -1 }
			if b < a { return 1 }
			return if *lhs < *rhs {
				-1
			} else if *lhs > *rhs {
				1
			} else {
				0
			}
		})
		ordered := order.map(items[it])
		for i, item in ordered { items[i] = item }
	})(mut values)
	println(values)
	println((fn (items []int) []int {
		keys := items.map(key(it))
		mut order := []int{len: items.len, init: index}
		order.sort_with_compare(fn [keys] (lhs &int, rhs &int) int {
			a := keys[*lhs]
			b := keys[*rhs]
			if a < b { return -1 }
			if b < a { return 1 }
			return if *lhs < *rhs {
				-1
			} else if *lhs > *rhs {
				1
			} else {
				0
			}
		})
		return order.map(items[it])
	})([5]))
}

fn main() {
	main_func()
}
