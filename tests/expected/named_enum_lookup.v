module main

import pyrt

pub enum Target {
	py39  = 9
	py312 = 12
}

pub fn (member Target) str() string {
	return match member {
		.py39 { 'Target.PY39' }
		.py312 { 'Target.PY312' }
	}
}

pub fn (member Target) py2v_enum_name() string {
	return match member {
		.py39 { 'PY39' }
		.py312 { 'PY312' }
	}
}

pub fn Target.py2v_enum_lookup(label string) !Target {
	return match label {
		'PY39' { .py39 }
		'PY312' { .py312 }
		else { return pyrt.key_error(pyrt.Value(label)) }
	}
}

fn (self Target) pretty() string {
	return 'Python ${(py2v_string_index1(self.py2v_enum_name(), 2, none) or { panic(err) })}.${py2v_slice_step1(self.py2v_enum_name().runes(), 3, ?int(none), 1).string()}'
}

pub enum Selection {
	stable  = 1
	preview = 2
}

pub fn (member Selection) str() string {
	return match member {
		.stable { 'Selection.stable' }
		.preview { 'Selection.preview' }
	}
}

pub fn (member Selection) py2v_enum_name() string {
	return match member {
		.stable { 'stable' }
		.preview { 'preview' }
	}
}

pub fn Selection.py2v_enum_lookup(label string) !Selection {
	return match label {
		'stable' { .stable }
		'preview' { .preview }
		else { return pyrt.key_error(pyrt.Value(label)) }
	}
}

fn lookup_target_py(label string) !Target {
	return Target.py2v_enum_lookup(label)!
}

fn lookup_options_py(labels []string) ![]Selection {
	return labels.map(Selection.py2v_enum_lookup(it)!)
}

fn py2v_string_index1(value string, index i64, index_error ?IError) !string {
	chars := value.runes()
	offset := if index < 0 { i64(chars.len) + index } else { index }
	if offset < 0 || offset >= i64(chars.len) {
		return index_error or { error('IndexError: string index out of range') }
	}
	return chars[int(offset)].str()
}

fn py2v_slice_step1[T](values []T, lower ?int, upper ?int, step int) []T {
	if step == 0 {
		panic('ValueError: slice step cannot be zero')
	}
	n := values.len
	min_index := if step < 0 { -1 } else { 0 }
	max_index := if step < 0 { n - 1 } else { n }
	mut start := if step < 0 { max_index } else { min_index }
	mut stop := if step < 0 { min_index } else { max_index }
	if bound := lower {
		offset := if bound < 0 { bound + n } else { bound }
		start = if offset < min_index {
			min_index
		} else if offset > max_index {
			max_index
		} else {
			offset
		}
	}
	if bound := upper {
		offset := if bound < 0 { bound + n } else { bound }
		stop = if offset < min_index {
			min_index
		} else if offset > max_index {
			max_index
		} else {
			offset
		}
	}
	mut result := []T{}
	for index := start; if step < 0 { index > stop } else { index < stop }; index += step {
		result << values[index]
		if (step < 0 && step <= stop - index) || (step > 0 && step >= stop - index) {
			break
		}
	}
	return result
}

fn py2v_entry1() ! {
	target := lookup_target_py('PY312')!
	println('${target} ${int(target)} ${target.py2v_enum_name()} ${target.pretty()}')
	for option in lookup_options_py(['preview', 'stable'])! {
		println('${option.py2v_enum_name()} ${int(option)}')
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		lookup_target_py('py312') or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'KeyError') != none {
			println('missing')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
