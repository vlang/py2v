module main

fn render_words(words []string, label ?string) string {
	if label != none {
		return label + '=' + words.join(':')
	}
	return 'words=' + words.join(':')
}

fn main() {
	println(render_words(['one', 'two'], 'custom'))
	println(render_words('éx'.runes().map(it.str()), none))
}
