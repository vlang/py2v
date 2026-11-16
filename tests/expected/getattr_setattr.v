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
	println(if val { 'True' } else { 'False' })
	println(if (typeof(c.level).name != '') { 'True' } else { 'False' })
	name := c.missing or { 'default' }
	println(name)
}

fn main() {
	show()
}
