@[translated]
module main

fn build(a Any, b Any, c Any, d Any, e Any, f Any, g Any, h Any, i Any, j Any, k Any, l Any) Any {
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
	text := ('prefix-' + a + '-' + b + '-' + c + '-' + d + '-' + e + '-' + f + '-' + g + '-' + h +
		'-' + i + '-' + j + '-' + k + '-' + l + '-suffix')
	return [items, text]
}

fn main() {
	out := build(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	println(out[0][0])
	println(out[1])
}

type Any = bool | int | i64 | f64 | string | []u8
