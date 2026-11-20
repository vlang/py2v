module main

fn main_func() {
	py2v_range_start1 := 0
	py2v_range_stop2 := 3
	py2v_range_step3 := 1
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		print(i)
	}
	println('')
	py2v_range_start4 := 0
	py2v_range_stop5 := 3
	py2v_range_step6 := 1
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start4; if py2v_range_step6 > 0 {
		i < py2v_range_stop5
	} else {
		i > py2v_range_stop5
	}; i = py2v_range_next1(i, py2v_range_stop5, py2v_range_step6) {
		print(i.str() + ' ')
	}
	println('')
	println('a-b-c')
	println('ab')
	print('${1}, ${2}, ${3}' + '!\n')
	print('no newline')
	println('')
	print(' ')
	println('after space')
	name := 'x'
	n := 4
	println('${name}=${n}')
	print('${name} ${n}' + ';\n')
	println(("it's").str() + "'" + ('quoted').str())
	println(('2.5').str() + '|' + (if true { 'True' } else { 'False' }).str())
	println('plain default')
	print('tab' + '\t')
	println('done')
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}

fn main() {
	main_func()
}
