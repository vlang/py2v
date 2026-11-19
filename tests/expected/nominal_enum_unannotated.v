module main

pub enum Flags {
	off = 0
	on  = 1
}

pub fn (member Flags) str() string {
	return match member {
		.off { 'Flags.OFF' }
		.on { 'Flags.ON' }
	}
}

// @classmethod
fn Flags.choose(active bool) Flags {
	return if active { Flags.on } else { Flags.off }
}

fn main() {
	println(Flags.choose(true))
	println(if Flags.choose(false) == Flags.off { 'True' } else { 'False' })
}
