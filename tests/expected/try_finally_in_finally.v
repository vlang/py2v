module main

fn run(mut log []string) int {
	defer {
		log << 'cleanup'
		log << 'close'
	}
	log << 'body'
	return 1
}

fn loop(mut log []string) {
	defer {
		for name in ['a', 'b'] {
			for part in [name, 'x'] {
				if part == 'x' {
					break
				}
				log << part
			}
			log << 'after ' + name
		}
	}
	log << 'start'
}

fn main() {
	mut log := []string{}
	println('${run(mut log)} ${log}')
	loop(mut log)
	println(log)
}
