module main

import pyrt

pub struct Pair {
pub mut:
	left  int
	right int
}

fn (mut self Pair) init(left int, right int) {
	self.left = left
	self.right = right
}

pub fn py2v_new_pair(left int, right int) Pair {
	mut py2v_instance := Pair{}
	py2v_instance.init(left, right)
	return py2v_instance
}

pub struct Token {
pub mut:
	text   string
	quoted bool
}

fn (mut self Token) init(text string, quoted bool) {
	self.text = text
	self.quoted = quoted
}

pub fn py2v_new_token(text string, quoted bool) Token {
	mut py2v_instance := Token{}
	py2v_instance.init(text, quoted)
	return py2v_instance
}

fn scalar_capture() {
	value := 4
	py2v_capture1 := &value
	build := fn [py2v_capture1] () Pair {
		return (fn [py2v_capture1] () Pair {
			py2v_init_arg2 := py2v_integer_add1((*py2v_capture1), 1, 'constructor_closure_captures.py:17', 'addition')
			py2v_init_arg3 := py2v_integer_mul1((*py2v_capture1), 2, 'constructor_closure_captures.py:17', 'multiplication')
			return py2v_new_pair(py2v_init_arg2, py2v_init_arg3)
		})()
	}
	pair := build()
	println('${pair.left} ${pair.right}')
}

fn token_capture() {
	letters := ['a', 'b']
	quoted := true
	py2v_capture4 := &letters
	py2v_capture5 := &quoted
	build := fn [py2v_capture4, py2v_capture5] () Token {
		return (fn [py2v_capture4, py2v_capture5] () Token {
			py2v_init_arg6 := (*py2v_capture4).join('')
			py2v_init_arg7 := (*py2v_capture5)
			return py2v_new_token(py2v_init_arg6, py2v_init_arg7)
		})()
	}
	token := build()
	println((token.text).str() + ' ' + (if token.quoted { 'True' } else { 'False' }).str())
}

fn mutable_capture() {
	mut items := pyrt.list_ref[int]([3, 7])
	py2v_capture8 := &items
	build := fn [py2v_capture8] () Pair {
		return (fn [py2v_capture8] () Pair {
			py2v_init_arg9 := (*py2v_capture8).items.pop()
			py2v_init_arg10 := (*py2v_capture8).items.len
			return py2v_new_pair(py2v_init_arg9, py2v_init_arg10)
		})()
	}
	pair := build()
	println('${pair.left} ${pair.right} ${items.items.len}')
}

fn nested_capture() {
	value := 6
	py2v_capture11 := &value
	middle := fn [py2v_capture11] () Pair {
		py2v_capture12 := &(*py2v_capture11)
		build := fn [py2v_capture12] () Pair {
			return (fn [py2v_capture12] () Pair {
				py2v_init_arg13 := py2v_integer_add1((*py2v_capture12), 2, 'constructor_closure_captures.py:49', 'addition')
				py2v_init_arg14 := py2v_integer_add1((*py2v_capture12), 3, 'constructor_closure_captures.py:49', 'addition')
				return py2v_new_pair(py2v_init_arg13, py2v_init_arg14)
			})()
		}
		return build()
	}
	pair := middle()
	println('${pair.left} ${pair.right}')
}

fn keyword_capture() {
	mut items := pyrt.list_ref[int]([2, 9])
	py2v_capture15 := &items
	build := fn [py2v_capture15] () Pair {
		return (fn [py2v_capture15] () Pair {
			py2v_init_arg16 := (*py2v_capture15).items.len
			py2v_init_arg17 := (*py2v_capture15).items.pop()
			return py2v_new_pair(py2v_init_arg17, py2v_init_arg16)
		})()
	}
	pair := build()
	println('${pair.left} ${pair.right} ${items.items.len}')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	scalar_capture()
	token_capture()
	mutable_capture()
	nested_capture()
	keyword_capture()
}
