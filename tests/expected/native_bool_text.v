module main

fn echo(flag bool) bool {
	println((py2v_bool_text1(flag)).str() + ' ' + ('${py2v_bool_text1(flag)}').str() + ' ' + ('${py2v_bool_text1(flag)}').str() + ' ' + ('${py2v_bool_text1(flag)}').str())
	return flag
}

fn py2v_bool_text1(value bool) string {
	return if value { 'True' } else { 'False' }
}

fn main() {
	mut flag := true
	flag = false
	println((py2v_bool_text1(flag)).str() + ' ' + ('${py2v_bool_text1(flag)}').str())
	println(if echo(true) { 'True' } else { 'False' })
	flags := [false, true]
	println((py2v_bool_text1(flags[0])).str() + ' ' + ('${py2v_bool_text1(flags[1])}').str() + ' ' + ('${py2v_bool_text1(1 > 2)}').str())
	names := ['True']
	if (py2v_bool_text1(flags[0]) !in names) {
		println('False is absent')
	}
}
