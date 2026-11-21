module main

fn show_characters(text string) {
	for offset, char_ in text.split('') {
		println(offset.str() + ' ' + char_.str() + ' ' + (if char_ == '♞' {
			'True'
		} else {
			'False'
		}).str())
	}
}

fn main() {
	show_characters('é♞a')
}
