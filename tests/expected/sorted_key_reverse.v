module main

import math

pub struct Item {
pub mut:
	name   string
	weight int
}

fn (mut self Item) init(name string, weight int) {
	self.name = name
	self.weight = weight
}

pub fn py2v_new_item(name string, weight int) Item {
	mut py2v_instance := Item{}
	py2v_instance.init(name, weight)
	return py2v_instance
}

fn heavy(item Item) int {
	return item.weight
}

fn negate(x int) int {
	return -x
}

fn main_func() {
	mut nums := [5, -3, 2, -8, 1]
	println(nums.sorted(a > b))
	println((fn (items []int) []int {
		keys := items.map(math.abs(it))
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
	})(nums))
	println((fn (items []int) []int {
		keys := items.map(math.abs(it))
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
	})(nums))
	println((fn (items []int) []int {
		keys := items.map(negate(it))
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
	})(nums))
	mut words := ['pear', 'Fig', 'apple', 'kiwi', 'Date']
	println((fn (items []string) []string {
		keys := items.map(it.len_utf8())
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
		keys := items.map(it.len_utf8())
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
	println((fn (items []string) []string {
		keys := items.map(it.to_lower())
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
	println(words.sorted(a > b))
	mut rows := [[3, 1], [1, 2], [2, 0], [1, 0]]
	println((fn (items [][]int) [][]int {
		keys := items.map(it[0])
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
	})(rows))
	println((fn (items [][]int) [][]int {
		keys := items.map(it[1])
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
	})(rows))
	mut items := [py2v_new_item('b', 2), py2v_new_item('a', 2), py2v_new_item('c', 1)]
	by_weight := (fn (items []Item) []Item {
		keys := items.map(it.weight)
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
	})(items)
	for item in by_weight {
		println('${item.name} ${item.weight}')
	}
	nums.sort(a > b)
	println(nums)
	(fn (mut items []int) {
		keys := items.map(math.abs(it))
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
		ordered := order.map(items[it])
		for i, item in ordered { items[i] = item }
	})(mut nums)
	println(nums)
	(fn (mut items []string) {
		keys := items.map(it.len_utf8())
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
		ordered := order.map(items[it])
		for i, item in ordered { items[i] = item }
	})(mut words)
	println(words)
	(fn (mut items []string) {
		keys := items.map(it.to_lower())
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
	})(mut words)
	println(words)
	(fn (mut items [][]int) {
		keys := items.map(it[1])
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
		ordered := order.map(items[it])
		for i, item in ordered { items[i] = item }
	})(mut rows)
	println(rows)
	(fn (mut items []Item) {
		keys := items.map(heavy(it))
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
	})(mut items)
	for item in items {
		println('${item.name} ${item.weight}')
	}
	(fn (mut items []Item) {
		keys := items.map(it.name)
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
		ordered := order.map(items[it])
		for i, item in ordered { items[i] = item }
	})(mut items)
	for item in items {
		println('${item.name} ${item.weight}')
	}
}

fn main() {
	main_func()
}
