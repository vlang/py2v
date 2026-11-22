module main

import arrays

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
	return py2v_integer_neg1(x, 'sorted_key_reverse.py:12')
}

fn main_func() {
	mut nums := [5, -3, 2, -8, 1]
	println(nums.sorted(a > b))
	println((fn (a []int) []int {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs int, rhs int) bool {
			return py2v_integer_abs1(lhs, 'sorted_key_reverse.py:18') < py2v_integer_abs1(rhs, 'sorted_key_reverse.py:18')
		})
		return b
	}(nums)))
	println((fn (a []int) []int {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs int, rhs int) bool {
			return py2v_integer_abs1(rhs, 'sorted_key_reverse.py:19') < py2v_integer_abs1(lhs, 'sorted_key_reverse.py:19')
		})
		return b
	}(nums)))
	println((fn (a []int) []int {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs int, rhs int) bool { return negate(lhs) < negate(rhs) })
		return b
	}(nums)))
	mut words := ['pear', 'Fig', 'apple', 'kiwi', 'Date']
	println((fn (a []string) []string {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs string, rhs string) bool { return lhs.len < rhs.len })
		return b
	}(words)))
	println((fn (a []string) []string {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs string, rhs string) bool { return rhs.len < lhs.len })
		return b
	}(words)))
	println((fn (a []string) []string {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs string, rhs string) bool {
			return lhs.to_lower() < rhs.to_lower()
		})
		return b
	}(words)))
	println(words.sorted(a > b))
	mut rows := [[3, 1], [1, 2], [2, 0], [1, 0]]
	println((fn (a [][]int) [][]int {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs []int, rhs []int) bool { return lhs[0] < rhs[0] })
		return b
	}(rows)))
	println((fn (a [][]int) [][]int {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs []int, rhs []int) bool { return rhs[1] < lhs[1] })
		return b
	}(rows)))
	mut items := [py2v_new_item('b', 2), py2v_new_item('a', 2), py2v_new_item('c', 1)]
	by_weight := (fn (a []Item) []Item {
		mut b := a.clone()
		arrays.stable_sort(mut b, fn (lhs Item, rhs Item) bool { return lhs.weight < rhs.weight })
		return b
	}(items))
	for item in by_weight {
		println('${item.name} ${item.weight}')
	}
	nums.sort(a > b)
	println(nums)
	arrays.stable_sort(mut nums, fn (lhs int, rhs int) bool {
		return py2v_integer_abs1(lhs, 'sorted_key_reverse.py:35') < py2v_integer_abs1(rhs, 'sorted_key_reverse.py:35')
	})
	println(nums)
	arrays.stable_sort(mut words, fn (lhs string, rhs string) bool { return lhs.len < rhs.len })
	println(words)
	arrays.stable_sort(mut words, fn (lhs string, rhs string) bool {
		return rhs.to_lower() < lhs.to_lower()
	})
	println(words)
	arrays.stable_sort(mut rows, fn (lhs []int, rhs []int) bool { return lhs[1] < rhs[1] })
	println(rows)
	arrays.stable_sort(mut items, fn (lhs Item, rhs Item) bool { return heavy(rhs) < heavy(lhs) })
	for item in items {
		println('${item.name} ${item.weight}')
	}
	arrays.stable_sort(mut items, fn (lhs Item, rhs Item) bool { return lhs.name < rhs.name })
	for item in items {
		println('${item.name} ${item.weight}')
	}
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_neg1(value int, site string) int {
	if value == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'negation') }
	return -value
}

@[inline]
fn py2v_integer_abs1(value int, site string) int {
	if value == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'absolute value') }
	return if value < 0 { -value } else { value }
}

fn main() {
	main_func()
}
