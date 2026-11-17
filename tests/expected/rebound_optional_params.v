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

fn flag(py2v_value_in2 ?bool) {
	mut value := py2v_value_in2
	if value == none {
		value = true
	}
	if value != none {
		if value {
			println('enabled')
		}
	}
}

fn overwrite(py2v_value_in3 ?string) {
	mut value := py2v_value_in3
	value = 'changed'
	if value != none {
		println(value)
	}
}

fn main() {
	text(none)
	text('given')
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
