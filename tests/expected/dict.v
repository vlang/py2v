module main

fn implicit_keys() bool {
	py2v_ident_43_4f_44_45_53 := {
		'KEY': 1
	}
	return 'KEY' in py2v_ident_43_4f_44_45_53
}

fn explicit_keys() bool {
	py2v_ident_43_4f_44_45_53_ := {
		'KEY': 1
	}
	return 'KEY' in py2v_ident_43_4f_44_45_53_.keys()
}

fn dict_values() bool {
	py2v_ident_43_4f_44_45_53__ := {
		'KEY': 1
	}
	return 1 in py2v_ident_43_4f_44_45_53__.keys().map(py2v_ident_43_4f_44_45_53__[it])
}

fn return_dict_index_str(key string) int {
	py2v_ident_43_4f_44_45_53___ := {
		'KEY': 1
	}
	return py2v_ident_43_4f_44_45_53___[key]
}

fn return_dict_index_int(key int) string {
	py2v_ident_43_4f_44_45_53____ := {
		1: 'one'
	}
	return py2v_ident_43_4f_44_45_53____[key]
}

fn main() {
	assert implicit_keys()
	assert explicit_keys()
	assert dict_values()
	assert return_dict_index_str('KEY') == 1
	assert return_dict_index_int(1) == 'one'
	println('OK')
}
