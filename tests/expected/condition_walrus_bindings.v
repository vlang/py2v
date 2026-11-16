module main

fn parameter(flag bool) {
	mut py2v_walrus_arg1 := flag
	py2v_walrus_arg1 = true
	if py2v_walrus_arg1 {
		println(('parameter').str() + ' ' + (if py2v_walrus_arg1 { 'True' } else { 'False' }).str())
	}
}

fn loop_binding() {
	mut flag := false
	for py2v_walrus_iter2 in [false, false] {
		flag = py2v_walrus_iter2
		flag = true
		if flag {
			println(('loop').str() + ' ' + (if flag { 'True' } else { 'False' }).str())
		}
	}
	println(('loop-after').str() + ' ' + (if flag { 'True' } else { 'False' }).str())
}

fn ignored() {
	mut py2v_walrus_name3 := false
	py2v_walrus_name3 = true
	if py2v_walrus_name3 {
		println(('underscore').str() + ' ' + (if py2v_walrus_name3 { 'True' } else { 'False' }).str())
	}
}

fn inferred() bool {
	mut answer := false
	answer = true
	if answer {
		return answer
	}
	return false
}

fn main() {
	module_flag := true
	if module_flag {
		println('module-set')
	}
	caller := false
	parameter(caller)
	println(('caller').str() + ' ' + (if caller { 'True' } else { 'False' }).str())
	loop_binding()
	ignored()
	println(if inferred() { 'True' } else { 'False' })
	println(if module_flag { 'True' } else { 'False' })
}
