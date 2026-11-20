module main

import pyrt

type Any = pyrt.Value

pub struct Settings {
pub mut:
	labels []string = ['left', 'right']
	kind   Any      = int
	limit  int      = 3
}

fn sentinel_map(values map[string]Any) map[string]Any {
	return values
}

fn class_argument(factory Any) Any {
	return factory(3)
}
