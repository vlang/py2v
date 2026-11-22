module main

fn first() []int {
	println('first')
	return [1, 2, 3]
}

fn second() []string {
	println('second')
	return ['a', 'b']
}

fn main() {
	py2v_zip_first1 := first()
	py2v_zip_second2 := second()
	py2v_zip_len3 := if py2v_zip_first1.len < py2v_zip_second2.len {
		py2v_zip_first1.len
	} else {
		py2v_zip_second2.len
	}
	for py2v_zip_index4 in 0 .. py2v_zip_len3 {
		a := py2v_zip_first1[py2v_zip_index4]
		b := py2v_zip_second2[py2v_zip_index4]
		println('${a}:${b}')
	}
	py2v_zip_first5 := second()
	py2v_zip_second6 := first()
	py2v_zip_len7 := if py2v_zip_first5.len < py2v_zip_second6.len {
		py2v_zip_first5.len
	} else {
		py2v_zip_second6.len
	}
	for py2v_zip_index8 in 0 .. py2v_zip_len7 {
		text := py2v_zip_first5[py2v_zip_index8]
		number := py2v_zip_second6[py2v_zip_index8]
		println('${text}:${number}')
	}
	py2v_zip_first9 := 'é🙂'.runes().map(it.str())
	py2v_zip_second10 := [1, 2, 3]
	py2v_zip_len11 := if py2v_zip_first9.len < py2v_zip_second10.len {
		py2v_zip_first9.len
	} else {
		py2v_zip_second10.len
	}
	for py2v_zip_index12 in 0 .. py2v_zip_len11 {
		character := py2v_zip_first9[py2v_zip_index12]
		number := py2v_zip_second10[py2v_zip_index12]
		println('${character}:${number}')
	}
}
