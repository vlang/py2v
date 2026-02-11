@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

fn build(a Any, b Any, c Any, d Any, e Any, f Any, g Any, h Any, i Any, j Any, k Any, l Any) {
	items := [
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
	]
	text := ('prefix-' + a.str() + '-' + b.str() + '-' + c.str() + '-' + d.str() + '-' + e.str() +
		'-' + f.str() + '-' + g.str() + '-' + h.str() + '-' + i.str() + '-' + j.str() + '-' +
		k.str() + '-' + l.str() + '-suffix')
	return [items, text]
}

fn main() {
	out := build(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	println((out[0][0]).str())
	println((out[1]).str())
}
