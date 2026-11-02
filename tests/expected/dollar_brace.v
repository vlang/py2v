module main

fn shell_guard(value string) bool {
	return value.starts_with('\${')
}

fn joined(value string) string {
	return 'a\${b}c' + value
}

fn braced(value string) string {
	return '\${not an expression}'
}

fn plain_dollar(value string) string {
	return 'costs $5 and $ alone'
}

fn main() {
	println(if shell_guard('\${x}') { 'True' } else { 'False' })
	println(joined('z'))
	println(braced('z'))
	println(plain_dollar('z'))
}
