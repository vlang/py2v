module main

fn source_name() string {
	return @FILE
}

fn main() {
	path := source_name()
	println(if path.len > 0 { 'True' } else { 'False' })
	println(if path.ends_with('.py') || path.ends_with('.v') { 'True' } else { 'False' })
	println(if @FILE == path { 'True' } else { 'False' })
}
