module main

fn loop(mut log []string) {
	defer {
		for name in ['a', 'b'] {
			py2v_unsupported_jump_out_of_try_finally_inside_finally()
			if name == 'a' {
				continue
			}
			log << name
			log << 'after ' + name
		}
	}
	log << 'start'
}

fn main() {
	mut log := []string{}
	loop(mut log)
	println(log)
}
