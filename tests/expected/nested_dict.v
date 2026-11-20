module main

fn nested_containers() bool {
	py2v_ident_43_4f_44_45_53 := {
		'KEY': [1, 3]
	}
	return 1 in py2v_ident_43_4f_44_45_53['KEY']
}

fn main() {
	if nested_containers() {
		println('OK')
	}
}
