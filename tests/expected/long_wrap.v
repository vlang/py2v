module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn build(a int, b int, c int, d int, e int, f int, g int, h int, i int, j int, k int, l int) Any {
	items := pyrt.list_ref[string]([
		'aaaaaaaaaa',
		'bbbbbbbbbb',
		'cccccccccc',
		'dddddddddd',
		'eeeeeeeeee',
		'ffffffffff',
		'gggggggggg',
		'hhhhhhhhhh',
		'iiiiiiiiii',
		'jjjjjjjjjj',
		'kkkkkkkkkk',
		'llllllllll',
		'mmmmmmmmmm',
		'nnnnnnnnnn',
	])
	text := 'prefix-${a}-${b}-${c}-${d}-${e}-${f}-${g}-${h}-${i}-${j}-${k}-${l}-suffix'
	return [items, text]
}

fn main() {
	out := build(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	println(pyrt.str(pyrt.item_at(pyrt.item_at(out, pyrt.box(0)), pyrt.box(0))))
	println(pyrt.str(pyrt.item_at(out, pyrt.box(1))))
}
