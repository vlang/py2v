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
	println(c)
	d := ([0].repeat(5))
	println(d)
	e := ([1, 2].repeat(3))
	println(e)
	println(a.len)
	println(c.len)
	println(c[0])
	println(c[c.len - 1])
}

fn main() {
	main_func()
}
