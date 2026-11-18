module main

import regex
import os
import pyrt.pathlib
import pyrt.sqlite3
import pyrt.re
import pyrt

fn one() int {
	println('called')
	return 1
}

fn false_probe() bool {
	println('false call')
	return false
}

fn callback() fn () int {
	println('callback')
	return one
}

fn path_probe(value pathlib.Path) pathlib.Path {
	println('path')
	return value
}

fn report(connection &sqlite3.Connection) {
	println(if !!pyrt.instance_truth(connection) { 'True' } else { 'False' })
	println(if !pyrt.instance_truth(connection) { 'True' } else { 'False' })
	if pyrt.instance_truth(connection) {
		println('connection')
	}
	path := pathlib.new_path('')
	if pyrt.instance_truth(path_probe(path)) {
		println('instance')
	}
	println(if !pyrt.instance_truth(path) { 'True' } else { 'False' })
	if pyrt.instance_truth(one) {
		println('function')
	}
	println(if !pyrt.instance_truth(one) { 'True' } else { 'False' })
	if pyrt.instance_truth(callback()) {
		println('factory')
	}
	if pyrt.instance_truth(false_probe) {
		println('bool function')
	}
	println(if !!false_probe() { 'True' } else { 'False' })
}

fn main() {
	connection := (sqlite3.connect(':memory:') or { pyrt.fail(err) })
	report(connection)
	connection.close() or { pyrt.fail(err) }
	println(if !!pyrt.instance_truth(connection) { 'True' } else { 'False' })
	one()
	missing := (re.search('z', '', 0) or { pyrt.fail(err) }).opt()
	empty := (re.search('', '', 0) or { pyrt.fail(err) }).opt()
	println(if missing != none { 'True' } else { 'False' })
	println(if empty != none { 'True' } else { 'False' })
}
