module main

import math.big as py2v_big

type Word = u64

const mask = u64(18446744073709551615)

fn show(word u64) {
	large := py2v_big.integer_from_string('1267650600228229401496703205376') or { panic(err) }
	println('${word} ${word.str()} ${word.hex()}')
	println((if py2v_cmp_u64_int1(word, i64(i64(9007199254740993))) > 0 { 'True' } else { 'False' }).str() + ' ' + (if word < mask {
		'True'
	} else {
		'False'
	}).str())
	println(large.str() + ' ' + (large.str()).str() + ' ' + ('${large}').str())
}

fn py2v_cmp_u64_int1(a u64, b i64) int {
	if b < 0 || a > u64(b) { return 1 }
	if a < u64(b) { return -1 }
	return 0
}

fn main() {
	high := u64(9223372036854775809)
	show(high)
}
