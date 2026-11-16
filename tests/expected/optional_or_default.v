module main

fn show(mode ?string, count ?int) string {
	label := if mode != none && mode != '' { mode } else { 'default' }
	size := if count != none && count != 0 { count } else { 7 }
	return label + size.str()
}

fn first(given ?string, other ?string) string {
	return if given != none && given != '' {
		given
	} else {
		if other != none && other != '' { other } else { 'neither' }
	}
}

fn main() {
	println((show('a', none)).str() + ' ' + (show(none, 0)).str() + ' ' + (show('', 2)).str() + ' ' + (show(none, 3)).str())
	println((first(none, 'b')).str() + ' ' + (first('a', 'b')).str() + ' ' + (first(none, none)).str() + ' ' + (first('', '')).str())
}
