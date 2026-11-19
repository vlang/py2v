module main

pub enum Choice {
	no  = 0
	yes = 1
}

pub fn (member Choice) str() string {
	return match member {
		.no { 'Choice.NO' }
		.yes { 'Choice.YES' }
	}
}

// @classmethod
fn Choice.pick(accept bool) Choice {
	return if accept { Choice.yes } else { Choice.no }
}

fn main() {
	println(Choice.pick(true))
	println(if Choice.pick(false) == Choice.no { 'True' } else { 'False' })
}
