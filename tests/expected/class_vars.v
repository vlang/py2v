module main

// Config holds application settings.
pub struct Config {
pub mut:
	debug       bool   = false
	max_retries int    = 3
	name        string = 'default'
	ratio       f64    = 0.5
}

const proxy_type_direct = 0
const proxy_type_manual = 1

pub struct ProxyType {
}

fn main() {
	c := Config{}
	println(if c.debug { 'True' } else { 'False' })
	println(c.max_retries)
	println(c.name)
	println(c.ratio)
	println(proxy_type_direct)
}
