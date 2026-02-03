@[translated]
module main

fn maybe_value(flag bool) int {
	if flag {
		return 42
	}

	return none
}

fn main_func() {
	x := none
	println(if x == none { 'True' } else { 'False' })
	println(if x != none { 'True' } else { 'False' })
	mut result := maybe_value(true)
	println(result.str())
	result = maybe_value(false)
	println(if result == none { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
