module main

fn mark(label string, value bool) bool {
	println(label)
	return value
}

fn number(label string, value int) int {
	println(label)
	return value
}

fn branch(first bool) {
	mut picked := false
	if first {
		println('first')
	} else {
		picked = mark('pick', true)
		if picked {
			println(('second').str() + ' ' + (if picked { 'True' } else { 'False' }).str())
		} else {
			println('fallback')
		}
	}
}

fn show() {
	mut old := 0
	mut x := false
	mut negative := false
	mut left := 0
	mut right := 0
	mut current := 0
	mut twice := 0
	mut skipped := false
	mut one := false
	mut two := false
	whole := mark('whole', true)
	if whole {
		println(('got').str() + ' ' + (if whole { 'True' } else { 'False' }).str())
	} else {
		println('miss')
	}
	println(('after').str() + ' ' + (if whole { 'True' } else { 'False' }).str())
	n := number('fresh', 3)
	if n > 2 {
		println('fresh-value ${n}')
	}
	old = 9
	old = number('replace', 4)
	if old > 2 {
		println('replace-value ${old}')
	}
	println('replace-after ${old}')
	a := false
	x = true
	mut py2v_walrus1 := a
	if py2v_walrus1 {
		x = mark('WRONG and', false)
		py2v_walrus1 = x
	}
	if py2v_walrus1 {
		println('WRONG and body')
	}
	println(('and-after').str() + ' ' + (if x { 'True' } else { 'False' }).str())
	negative = mark('not', false)
	if !negative {
		println(('not-value').str() + ' ' + (if negative { 'True' } else { 'False' }).str())
	}
	println(('not-after').str() + ' ' + (if negative { 'True' } else { 'False' }).str())
	branch(true)
	branch(false)
	left = number('left', 2)
	py2v_walrus2 := left
	right = number('right', 3)
	if py2v_walrus2 < right {
		println('pair ${left} ${right}')
	}
	current = 1
	py2v_walrus3 := current
	current = 2
	if py2v_walrus3 < current {
		println('snapshot ${current}')
	}
	twice = number('twice-first', 1)
	py2v_walrus4 := twice
	twice = number('twice-second', 2)
	if py2v_walrus4 < twice {
		println('twice ${twice}')
	}
	keep := true
	mut py2v_walrus5 := keep
	if !py2v_walrus5 {
		skipped = mark('WRONG or', true)
		py2v_walrus5 = skipped
	}
	if py2v_walrus5 {
		println('or-kept')
	}
	one = mark('one', true)
	mut py2v_walrus6 := one
	if py2v_walrus6 {
		two = mark('two', false)
		py2v_walrus6 = two
	}
	if py2v_walrus6 {
		println('WRONG pair body')
	} else {
		println(('two-values').str() + ' ' + (if one { 'True' } else { 'False' }).str() + ' ' + (if two {
			'True'
		} else {
			'False'
		}).str())
	}
}

fn main() {
	show()
}
