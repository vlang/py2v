module main

import pyrt.json
import pyrt

type Any = pyrt.Value

fn schema(name string, count int) map[string]Any {
	return {
		'name':       pyrt.box(name)
		'type':       pyrt.box('object')
		'count':      pyrt.box(count)
		'properties': pyrt.box(map[string]Any{
			'object_id': pyrt.box(map[string]Any{
				'type':        pyrt.box('string')
				'description': pyrt.box('the id')
			})
			'limit':     pyrt.box(map[string]Any{
				'type':    pyrt.box('integer')
				'default': pyrt.box(10)
			})
		})
		'required':   pyrt.box([pyrt.box('object_id')])
		'evidence':   pyrt.box(map[string]Any{
			'status':    pyrt.box(if count > 0 { 'attached' } else { 'none' })
			'inherited': pyrt.box(count)
		})
	}
}

fn main_func_py() ! {
	s := schema('capsule', 2)
	println(json.dumps(pyrt.box(s), sort_keys: true)!)
	println(pyrt.str(pyrt.item_at(pyrt.item_at(s['properties'], pyrt.box('limit')), pyrt.box('default'))))
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
