module main

pub struct Config {
pub mut:
	debug bool = false
	level int  = 1
}

fn show() {
	c := Config{}
	c.debug = true
	val := c.debug
	println(val)
	println((typeof(c.level).name != ''))
	name := c.missing or { 'default' }
	println(name)
}

fn main() {
	show()
}
