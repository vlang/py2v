module main

fn total(items []int) int {
	mut count := 0
	for item in items {
		count += item
	}
	return count
}

fn describe(count int) string {
	return 'n=' + count.str()
}

fn twice(n int) int {
	count := n
	return count * 2
}

fn inner(count int) int {
	return count + 1
}

fn other() int {
	count := 10
	return count * 3
}

fn outer() int {
	return inner(1) + other()
}

fn main() {
	mut count := 'three'
	numbers := [int(1), 2]
	println(total(numbers))
	println(describe(4))
	println(twice(5))
	println(count)
	println(outer())
}
