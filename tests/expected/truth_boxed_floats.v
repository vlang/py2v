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

fn report(flag bool, value Any) {
	println(pyrt.str(if flag { pyrt.box(pyrt.to_float(pyrt.box(0))) } else { value }))
	println(pyrt.str(if flag { value } else { pyrt.box(pyrt.to_float(pyrt.box(2))) }))
	println(pyrt.str(if flag { pyrt.box(-pyrt.to_float(pyrt.box(0))) } else { value }))
	println(pyrt.str(if flag {
		pyrt.box([
			pyrt.box(pyrt.to_float(pyrt.box(0))),
			pyrt.box(-pyrt.to_float(pyrt.box(0))),
			pyrt.box(+pyrt.to_float(pyrt.box(2))),
			pyrt.box(pyrt.to_float(pyrt.box(1.25))),
		])
	} else {
		value
	}))
	println(pyrt.str(if flag {
		value
	} else {
		pyrt.box(map[string]Any{
			'key': pyrt.box([pyrt.box(pyrt.to_float(pyrt.box(0))),
				pyrt.box(-pyrt.to_float(pyrt.box(0))), pyrt.box(pyrt.to_float(pyrt.box(2)))])
		})
	}))
}

fn main() {
	report(true, 'text')
	report(false, 'text')
}
