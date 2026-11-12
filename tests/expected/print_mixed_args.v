module main

fn main() {
	a := [1, 2]
	b := [3]
	c := [4, 5, 6]
	n := 7
	println((a.len).str() + ' ' + (b.len).str() + ' ' + n.str() + ' ' + (c.len).str())
	println((1).str() + ' ' + (2.5).str() + ' ' + ('word').str() + ' ' + (if true {
		'True'
	} else {
		'False'
	}).str() + ' ' + ([1, 2]).str())
	println(((2 + 3) * 4).str() + ' ' + (n - 1).str() + ' ' + ('n=${n}').str())
}
