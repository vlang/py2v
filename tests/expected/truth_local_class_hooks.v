module main

import pyrt

pub struct EmptyBool {
}

fn (self EmptyBool) to_bool() bool {
	println('bool-hook')
	return false
}

pub struct EmptyLength {
}

fn (self EmptyLength) len() int {
	println('len-hook')
	return 0
}

pub struct FullLength {
}

fn (self FullLength) len() int {
	println('full-len-hook')
	return 3
}

pub struct Both {
}

fn (self Both) to_bool() bool {
	println('both-bool-hook')
	return true
}

fn (self Both) len() int {
	println('bad-both-len-hook')
	return 0
}

pub struct Plain {
}

fn make_plain() Plain {
	println('make-plain')
	return Plain{}
}

fn report() {
	a := EmptyBool{}
	b := EmptyLength{}
	c := FullLength{}
	d := Both{}
	e := Plain{}
	println(if !a.to_bool() { 'True' } else { 'False' })
	println(if !!pyrt.truth_length(b.len()) { 'True' } else { 'False' })
	println(if !!pyrt.truth_length(c.len()) { 'True' } else { 'False' })
	println(if !d.to_bool() { 'True' } else { 'False' })
	println(if !pyrt.instance_truth(e) { 'True' } else { 'False' })
	if a.to_bool() {
		println('bad-a')
	} else {
		println('a-false')
	}
	if pyrt.truth_length(b.len()) {
		println('bad-b')
	} else {
		println('b-false')
	}
	if pyrt.truth_length(c.len()) {
		println('c-true')
	}
	if d.to_bool() {
		println('d-true')
	}
	if pyrt.instance_truth(e) {
		println('e-true')
	}
	if pyrt.instance_truth(make_plain()) {
		println('factory-true')
	}
}

fn main() {
	report()
}
