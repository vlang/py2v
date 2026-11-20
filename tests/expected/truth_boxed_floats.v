module main

import pyrt

type Any = pyrt.Value

fn report(flag bool, value Any) {
	println(pyrt.str(if flag { pyrt.box(pyrt.to_float(pyrt.box(0.0))) } else { value }))
	println(pyrt.str(if flag { value } else { pyrt.box(pyrt.to_float(pyrt.box(2.0))) }))
	println(pyrt.str(if flag { pyrt.box(-pyrt.to_float(pyrt.box(0.0))) } else { value }))
	println(pyrt.str(if flag {
		pyrt.box([
			pyrt.box(pyrt.to_float(pyrt.box(0.0))),
			pyrt.box(-pyrt.to_float(pyrt.box(0.0))),
			pyrt.box(+pyrt.to_float(pyrt.box(2.0))),
			pyrt.box(pyrt.to_float(pyrt.box(1.25))),
		])
	} else {
		value
	}))
	println(pyrt.str(if flag {
		value
	} else {
		pyrt.box(map[string]Any{
			'key': pyrt.box([pyrt.box(pyrt.to_float(pyrt.box(0.0))),
				pyrt.box(-pyrt.to_float(pyrt.box(0.0))), pyrt.box(pyrt.to_float(pyrt.box(2.0)))])
		})
	}))
}

fn main() {
	report(true, 'text')
	report(false, 'text')
}
