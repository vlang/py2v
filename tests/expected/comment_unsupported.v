@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

fn do_unsupported() {
	a := 1
	(fn () map[string]Any {
		mut result := map[string]Any{}
		for [key, value] in {} {
			result[(key + 1)] = (value + 1)
		}
		return result
	}())
	b := (a != 0)
	println(if b { 'True' } else { 'False' })
}

fn main() {
	do_unsupported()
}
