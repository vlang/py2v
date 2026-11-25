module main

fn f(flag bool) int {
	mut x := 0
	mut py2v_walrus1 := flag
	if py2v_walrus1 {
		x = 10
		py2v_walrus1 = x > 0
	}
	if py2v_walrus1 {
		// pass
	}
	for py2v_walrus_iter2 in [1, 2] {
		x = py2v_walrus_iter2
		py2v_range_stop4 := int(0)
		for py2v_walrus_iter3 in int(0) .. py2v_range_stop4 {
			x = py2v_walrus_iter3
			// pass
		}
	}
	return x
}

fn g(flag bool) int {
	mut x := 0
	mut py2v_walrus5 := flag
	if py2v_walrus5 {
		x = 10
		py2v_walrus5 = x > 0
	}
	if py2v_walrus5 {
		// pass
	}
	for py2v_walrus_iter6 in [1, 2] {
		x = py2v_walrus_iter6
		for py2v_walrus_iter7 in [3, 4] {
			x = py2v_walrus_iter7
			// pass
		}
	}
	return x
}

fn main() {
	println(f(false))
	println(f(true))
	println(g(false))
	println(g(true))
}
