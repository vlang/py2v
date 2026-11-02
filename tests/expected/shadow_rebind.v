module main

type Any = bool | int | i64 | f64 | string | []u8

fn collect(path Any) Any {
	return path
}

fn first_existing(mut path Any) Any {
	for path_ in collect(path_) {
		println(path_)
	}
	return path
}

fn rebind_local(items Any) int {
	mut total := 0
	for total_ in items {
		println(total_)
	}
	return total
}

fn destructure(mut path Any, rows Any) {
	py2v_seq1 := rows
	for py2v_item2 in py2v_seq1 {
		name := py2v_item2[0]
		path_ := py2v_item2[1]
		value := py2v_item2[2]
		println(name + ' ' + path_ + ' ' + value)
	}
}

fn main() {
	first_existing(mut 1)
	rebind_local([1, 2].map(Any(it)))
	destructure(mut 'p', [[1, 2, 3]].map(Any(it)))
}
