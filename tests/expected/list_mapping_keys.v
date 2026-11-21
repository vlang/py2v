module main

import pyrt

type Any = pyrt.Value

fn read_config() map[string]Any {
	return {
		'zeta':  pyrt.box(2)
		'alpha': pyrt.box('value')
	}
}

fn show_keys(keys []string) {
	println(keys.join(':'))
}

fn main() {
	config := read_config()
	show_keys(config.keys())
}
