module main

import pyrt

type Any = pyrt.Value

fn show(value Any) {
	println(if (pyrt.type_name(value) in ['int', 'bool']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['bool']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['float']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['str']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['bytes']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['list']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['dict']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['tuple']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['str', 'int', 'bool']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['int', 'bool']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['bool', 'int']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['int', 'bool']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(value) in ['float']) { 'True' } else { 'False' })
	println(if pyrt.type_name(value) == '' { 'True' } else { 'False' })
}

fn subject() Any {
	println('subject')
	return 'text'
}

fn once() {
	println(if (pyrt.type_name(subject()) in ['int', 'bool', 'str']) { 'True' } else { 'False' })
	println(if pyrt.type_name(subject()) == '' { 'True' } else { 'False' })
}

fn nested(record map[string]Any) {
	println(if (pyrt.type_name(record['value']) in ['list']) { 'True' } else { 'False' })
	println(if (pyrt.type_name(pyrt.item_at(record['value'], pyrt.box(0))) in ['int', 'bool']) {
		'True'
	} else {
		'False'
	})
	println(if (pyrt.type_name(Any(pyrt.map_get(record, 'missing', pyrt.none_))) in ['str']) {
		'True'
	} else {
		'False'
	})
}

fn main() {
	show(3)
	show(true)
	show(2.5)
	show('text')
	show([u8(0x62), 0x79, 0x74, 0x65, 0x73])
	show(pyrt.box([pyrt.box(1)]))
	show(pyrt.box(map[string]Any{
		'key': pyrt.box(2)
	}))
	show(pyrt.none_)
	once()
	nested(map[string]Any{
		'value': pyrt.box([pyrt.box(1)])
	})
}
