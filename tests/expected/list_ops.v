@[translated]
module main

fn main_func() {
	a := [1, 2, 3]
	b := [4, 5, 6]
	c := (fn [a, b] () []int {
		mut r := a.clone()
		r << b
		return r
	}())
	println(c.str())
	d := ([0].repeat(5))
	println(d.str())
	e := ([1, 2].repeat(3))
	println(e.str())
	println((a.len).str())
	println((c.len).str())
	println((c[0]).str())
	println((c[c.len - 1]).str())
}

fn main() {
	main_func()
}
