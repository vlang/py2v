module main

fn main_func() {
	fruits := ['apple', 'banana', 'cherry']
	for i, fruit in fruits {
		println(i)
		println(fruit)
	}
	names := ['Alice', 'Bob']
	ages := [25, 30]
	py2v_zip_first1 := names
	py2v_zip_second2 := ages
	py2v_zip_len3 := if py2v_zip_first1.len < py2v_zip_second2.len {
		py2v_zip_first1.len
	} else {
		py2v_zip_second2.len
	}
	for py2v_zip_index4 in 0 .. py2v_zip_len3 {
		name := py2v_zip_first1[py2v_zip_index4]
		age := py2v_zip_second2[py2v_zip_index4]
		println(name)
		println(age)
	}
}

fn main() {
	main_func()
}
