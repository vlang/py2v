module main

import pyrt.json
import pyrt

type Any = pyrt.Value

fn payload_py() !Any {
	return json.loads('{\"name\": \"ada\", \"words\": [\"cat\", \"dog\"]}')!
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

fn invoke_from_list_py(callbacks []Any) !Any {
	result := pyrt.call(callbacks[0], [])!
	return pyrt.item_at(result, pyrt.box(0))
}

fn py2v_entry1() ! {
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(payload_py()!, pyrt.box('name'))), 'upper', [])!))
	println(pyrt.str(pyrt.item_at(pyrt.item_at(payload_py()!, pyrt.box('words')), pyrt.box(0))))
	for word in pyrt.elements(pyrt.item_at(payload_py()!, pyrt.box('words'))) {
		println(pyrt.str(pyrt.call_method(pyrt.box(word), 'upper', [])!))
	}
	println(if pyrt.has(payload_py()!, pyrt.box('name')) { 'True' } else { 'False' })
	println(pyrt.length(words()))
	println(pyrt.str(pyrt.box(pyrt.elements(words()).map(pyrt.call_method(pyrt.box(it), 'upper', [])!))))
	println(pyrt.str(pyrt.call_method(pyrt.box(text()), 'strip', [])!))
	println(pyrt.str(nothing()))
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
