module main

fn main_func() {
	mut py2v_broke1 := false
	for x in [1, 2, 3] {
		if x == 2 {
			println(('found').str() + ' ' + x.str())
			py2v_broke1 = true
			break
		}
	}
	if !py2v_broke1 {
		println('missing')
	}
	mut py2v_broke2 := false
	for x in [1, 2, 3] {
		if x == 5 {
			py2v_broke2 = true
			break
		}
	}
	if !py2v_broke2 {
		println('no 5')
	}
	mut py2v_broke4 := false
	for i in []int{len: 4, init: index} {
		mut py2v_broke3 := false
		for j in []int{len: 4, init: index} {
			if j > i {
				py2v_broke3 = true
				break
			}
		}
		if !py2v_broke3 {
			println(('inner done').str() + ' ' + i.str())
		}
		if i == 2 {
			py2v_broke4 = true
			break
		}
	}
	if !py2v_broke4 {
		println('outer done')
	}
	mut n := 5
	mut py2v_broke5 := false
	for n > 0 {
		n -= 1
		if n == 2 {
			println(('stopped at').str() + ' ' + n.str())
			py2v_broke5 = true
			break
		}
	}
	if !py2v_broke5 {
		println('ran out')
	}
	mut k := 0
	for k < 3 {
		k += 1
	}
	println(('counted').str() + ' ' + k.str())
}

fn main() {
	main_func()
}
