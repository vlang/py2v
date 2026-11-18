module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
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

fn tokenize(src string) []Token {
	mut tokens := []Token{}
	mut cur := ''
	py2v_capture1 := &cur
	py2v_capture2 := &tokens
	end_token := fn [py2v_capture1, py2v_capture2] () {
		if (*py2v_capture1) != '' {
			(*py2v_capture2) << py2v_new_token((*py2v_capture1), false)
			unsafe {
				(*py2v_capture1) = ''
			}
		}
	}
	for ch in src.split('') {
		if ch == ' ' {
			end_token()
		} else {
			cur += ch
		}
	}
	end_token()
	return tokens
}

fn main() {
	for token in tokenize('ab c') {
		println((token.text).str() + ' ' + (if token.quoted { 'True' } else { 'False' }).str())
	}
}
