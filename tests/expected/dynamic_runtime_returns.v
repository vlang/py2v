module main

import pyrt.json
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

fn payload_py() !Any {
	return json.loads('{\"name\": \"ada\", \"words\": [\"cat\", \"dog\"]}')!
}

fn payload() Any {
	return payload_py() or { pyrt.fail(err) }
}

fn words() Any {
	return pyrt.box([pyrt.box('cat'), pyrt.box('dog')])
}

fn text() Any {
	return '  ada  '
}

fn nothing() Any {
	return pyrt.none_
}

fn invoke_callback_py(callback Any) !Any {
	result := pyrt.call(callback, [])!
	return pyrt.item_at(result, pyrt.box(0))
}

fn invoke_callback(callback Any) Any {
	return invoke_callback_py(callback) or { pyrt.fail(err) }
}

fn invoke_from_list_py(callbacks []Any) !Any {
	result := pyrt.call(callbacks[0], [])!
	return pyrt.item_at(result, pyrt.box(0))
}

fn invoke_from_list(callbacks []Any) Any {
	return invoke_from_list_py(callbacks) or { pyrt.fail(err) }
}

fn main() {
	println(pyrt.str(pyrt.invoke(pyrt.item_at(payload(), pyrt.box('name')), 'upper')))
	println(pyrt.str(pyrt.item_at(pyrt.item_at(payload(), pyrt.box('words')), pyrt.box(0))))
	for word in pyrt.elements(pyrt.item_at(payload(), pyrt.box('words'))) {
		println(pyrt.str(pyrt.invoke(word, 'upper')))
	}
	println(if pyrt.has(payload(), pyrt.box('name')) { 'True' } else { 'False' })
	println(pyrt.length(words()))
	println(pyrt.str(pyrt.box(pyrt.elements(words()).map(pyrt.invoke(it, 'upper')))))
	println(pyrt.str(pyrt.invoke(text(), 'strip')))
	println(pyrt.str(nothing()))
}
