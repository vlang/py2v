module main

import pyrt

fn main_func() {
	words := ['İ', 'i', 'ẞ', 'ß', 'K', 'K', 'σ', 'Σ', 'ǅ', 'ǆ']
	println((fn (items []string) []string {
		keys := items.map(pyrt.str(pyrt.lower(it) or { panic(err.msg()) }))
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
	})(words))
	println((fn (items []string) []string {
		keys := items.map(pyrt.str(pyrt.upper(it) or { panic(err.msg()) }))
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
	})(words))
	println((fn (items []string) []string {
		keys := items.map(pyrt.str(pyrt.lower(it) or { panic(err.msg()) }))
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
		return order.map(items[it])
	})(words))
}

fn main() {
	main_func()
}
