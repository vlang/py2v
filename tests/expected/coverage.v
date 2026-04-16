@[translated]
module main

fn inline_pass() {
	// pass
}

fn inline_ellipsis() {
	// ...
}

fn indexing() int {
	mut sum := 0
	mut a := []int{}
	for i in []int{len: 10, init: index} {
		a << i
		sum += a[i]
	}
	return sum
}

fn infer_bool(code int) bool {
	return code in [1, 2, 4]
}

fn show() {
	mut a1 := 10
	b1 := 15
	b2 := 15
	assert b1 == 15
	assert b2 == 15
	b9 := 2
	b10 := 2
	assert b9 == b10
	a2 := 2.1
	println(a2)
	for i in []int{len: 10 - 0, init: index + 0} {
		println(i)
	}
	for i := 0; i < 10; i += 2 {
		println(i)
	}
	a3 := -a1
	a4 := a3 + a1
	println(a4)
	t1 := if a1 > 5 { 10 } else { 5 }
	assert t1 == 10
	sum1 := indexing()
	println(sum1)
	a5 := [1, 2, 3]
	println(a5.len)
	a9 := ['a', 'b', 'c', 'd']
	println(a9.len)
	a7 := {
		'a': 1
		'b': 2
	}
	println(a7.len)
	a8 := true
	if a8 {
		println('true')
	} else if a4 > 0 {
		println('never get here')
	}
	if a1 == 11 {
		println('false')
	} else {
		println('true')
	}
	if 1 != 0 {
		println('World is sane')
	}
	println(if true { 'True' } else { 'False' })
	if true {
		a1 += 1
	}
	assert a1 == 11
	if true {
		println('true')
	}
	inline_pass()
	s := '1    2'
	println(s)
	assert infer_bool(1)
	_escape_quotes := ' foo "bar" baz '
	assert 'aaabbccc'.contains('bbc')
	assert 1 != 0
	_c1, _, _c2 = 1, 2, 3
}

fn main() {
	show()
}
