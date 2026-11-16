module main

fn hint(path string, start int) string {
	return 'don\'t read ${path} whole: sed -n \'${start}p\' ${path} | jq \'select(.type=="user")\' | cut -c1-400'
}

fn quoted(name string) string {
	return 'say "${name}" and it\'s done'
}

fn single(name string) string {
	return "it's ${name}"
}

fn main() {
	println(hint('log.jsonl', 3))
	println(quoted('x'))
	println(single('y'))
}
