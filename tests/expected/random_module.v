module main

import rand
import arrays

fn roll(sides int) int {
	return rand.int_in_range(1, sides + 1) or { panic(err) }
}

fn main() {
	rolls := []int{len: 200, init: index}.map(roll(6))
	println((if (arrays.min(rolls) or { panic('!') }) >= 1 { 'True' } else { 'False' }).str() + ' ' + (if (arrays.max(rolls) or { panic('!') }) <= 6 {
		'True'
	} else {
		'False'
	}).str() + ' ' + (rolls.len).str())
	println(if (6 in rolls) { 'True' } else { 'False' })
	value := rand.f64()
	println(if value >= 0 && value < 1 { 'True' } else { 'False' })
	names := ['ada', 'bob', 'cy']
	println(if ((rand.element(names) or { panic(err) }) in names) { 'True' } else { 'False' })
	mut deck := [1, 2, 3, 4, 5, 6, 7, 8]
	rand.shuffle(mut deck) or { panic(err) }
	println('${deck.sorted()} ${deck.len}')
	below := (rand.intn(10) or { panic(err) })
	between := (rand.int_in_range(5, 8) or { panic(err) })
	println((if below >= 0 && below < 10 { 'True' } else { 'False' }).str() + ' ' + (if between >= 5 && between < 8 {
		'True'
	} else {
		'False'
	}).str())
	picked := (rand.choose(deck, 3) or { panic(err) })
	println((picked.len).str() + ' ' + (if (picked[0] in deck) { 'True' } else { 'False' }).str())
	height := (rand.f64_in_range(1.5, 2.5) or { panic(err) })
	println(if height >= 1.5 && height <= 2.5 { 'True' } else { 'False' })
	pair := (rand.int_in_range(3, 4 + 1) or { panic(err) })
	println(if pair >= 3 && pair <= 4 { 'True' } else { 'False' })
	mut hand := [9, 8, 7]
	rand.shuffle(mut hand) or { panic(err) }
	println(hand.sorted())
}
