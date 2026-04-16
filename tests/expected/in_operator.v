@[translated]
module main

fn main_func() {
	nums := [1, 2, 3, 4, 5]
	println(if 3 in nums { 'True' } else { 'False' })
	println(if 10 in nums { 'True' } else { 'False' })
	println(if 10 !in nums { 'True' } else { 'False' })
	s := 'hello world'
	println(if s.contains('world') { 'True' } else { 'False' })
	println(if s.contains('xyz') { 'True' } else { 'False' })
	println(if !s.contains('xyz') { 'True' } else { 'False' })
	d := {
		'a': 1
		'b': 2
	}
	println(if 'a' in d { 'True' } else { 'False' })
	println(if 'c' in d { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
