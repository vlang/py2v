module main

fn native_text() {
	record := map[string]string{
		'full':  'text'
		'empty': ''
	}
	if record['full'] != '' {
		println('native')
	}
	println(if !(record['empty'] != '') { 'True' } else { 'False' })
}

fn report(items []int, data map[string]int) {
	println((if items.len > 0 { items } else { []int{} }).len)
	println((if items.len > 0 { [8] } else { items }).len)
	println((if data.len > 0 { data } else { map[string]int{} }).len)
	println((if data.len > 0 {
		({
			'selected': 9
		})
	} else {
		data
	}).len)
	println((if data.len > 0 {
		data
	} else {
		({
			'default': 7
		})
	}).len)
}

fn main() {
	native_text()
	empty := map[string]int{}
	full := {
		'key':   1
		'other': 2
	}
	report([], empty)
	report([1, 2], full)
}
