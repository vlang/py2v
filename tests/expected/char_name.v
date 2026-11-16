module main

fn shout(char_ string) string {
	return char_.to_upper() + '!'
}

fn count_vowels(text string) int {
	mut total := 0
	for char_ in text.split('') {
		if 'aeiou'.contains(char_) {
			total += 1
		}
	}
	return total
}

fn main_func() {
	println(shout('a'))
	println(count_vowels('education'))
	char_ := 'z'
	println(char_)
	letters := 'xyz'.split('').map(it)
	println(letters)
}

fn main() {
	main_func()
}
