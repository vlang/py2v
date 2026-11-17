module main

fn text(py2v_value_in1 ?string) {
	mut value := py2v_value_in1
	if value == none {
		value = 'fallback'
	}
	if value != none {
		println(value)
	}
}

fn number(py2v_value_in2 ?int) {
	mut value := py2v_value_in2
	if value == none {
		value = 7
	}
	if value != none {
		println(value)
	}
}

fn fraction(py2v_value_in3 ?f64) {
	mut value := py2v_value_in3
	if value == none {
		value = 1.5
	}
	if value != none {
		println(value)
	}
}

fn flag(py2v_value_in4 ?bool) {
	mut value := py2v_value_in4
	if value == none {
		value = true
	}
	if value != none {
		if value {
			println('enabled')
		}
	}
}

fn overwrite(py2v_value_in5 ?string) {
	mut value := py2v_value_in5
	value = 'changed'
	if value != none {
		println(value)
	}
}

fn main() {
	text(none)
	text('given')
	number(none)
	fraction(none)
	flag(none)
	mut caller := 'original'
	overwrite(caller)
	println(caller)
	mut caller_none := ?string(none)
	overwrite(caller_none)
	if caller_none == none {
		println('caller-none')
	}
}
