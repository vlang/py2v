module main

pub struct Policy {
pub mut:
	name    string
	tags    []string
	limits  map[string]int
	retries int     = 3
	note    ?string = none
	weight  f64     = 1.5
	seen    []string
}

fn main_func() {
	mut a := Policy{
		name: 'a'
	}
	b := Policy{
		name:    'b'
		tags:    ['x']
		retries: 5
	}
	a.tags << 'only-a'
	a.limits['cpu'] = 2
	println((a.name).str() + ' ' + (a.tags).str() + ' ' + (a.limits).str() + ' ' + (a.retries).str() + ' ' + (if a.note == none {
		'True'
	} else {
		'False'
	}).str() + ' ' + (a.weight).str())
	println('${b.name} ${b.tags} ${b.limits} ${b.retries} ${b.weight}')
	println(a.seen.len)
}

fn main() {
	main_func()
}
