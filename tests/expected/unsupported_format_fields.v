module main

fn display(value string, amount f64, precision int) string {
	return py2v_unsupported_str_format('{!r}: {:,.{precision}f}', value, amount, 'precision', precision)
}

fn named(value string) string {
	return py2v_unsupported_str_format('{{label}} {name!r}', 'name', value)
}

fn alternate_form(value int) string {
	return py2v_unsupported_str_format('<value={:#x}>', value)
}
