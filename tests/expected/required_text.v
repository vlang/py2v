module main

fn find(path ?string) ?string {
	return path
}

fn describe(path string) string {
	return '[' + path + ']'
}

fn report(py2v_path_in1 ?string, fallback ?string) ?string {
	mut path := py2v_path_in1
	if !(path != none && path != '') {
		path = find(fallback)
		if path == none {
			return none
		}
	}
	return describe((path or { panic('unreachable None after string narrowing') }))
}

fn main() {
	result := report(none, 'found')
	if result != none {
		println(result)
	}
	println(if report(none, none) == none { 'True' } else { 'False' })
}
