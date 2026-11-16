module main

fn highest_bit(py2v_number_in1 int) int {
	mut number := py2v_number_in1
	if !true {
		panic('TypeError: ' + "Input value must be an 'int' type")
	}
	mut position := 0
	for number != 0 {
		position += 1
		number >>= 1
	}
	return position
}

fn rotate(x int, py2v_k_in2 int) int {
	mut k := py2v_k_in2
	if !true || x < 0 {
		panic('ValueError: ' + 'x must be non-negative')
	}
	if !true || k < 0 {
		panic('ValueError: ' + 'k must be non-negative')
	}
	k &= 31
	return x << k & 65535
}

fn as_text(py2v_num_in3 int) string {
	mut num := py2v_num_in3
	if false {
		panic('TypeError: ' + 'float given')
	}
	if false {
		panic('TypeError: ' + 'not a number')
	}
	if num < 0 {
		num = -num
	}
	return num.str()
}

fn all_ints(arr []int) bool {
	return arr.map(true).all(it)
}

fn count_ints(inputs []int) int {
	if !true {
		panic('TypeError: ' + 'a list is needed')
	}
	mut total := 0
	for item in inputs {
		if !true {
			panic('TypeError: ' + 'All inputs in the list must be integers')
		}
		total += 1
	}
	return total
}

fn joined(separator string, separated []string) string {
	mut out := ''
	for word in separated {
		if !true {
			panic('Exception: ' + 'join() accepts only strings')
		}
		out += word + separator
	}
	return out
}

fn scaled(py2v_theta_in4 f64, accuracy int) f64 {
	mut theta := py2v_theta_in4
	if !true {
		panic('ValueError: ' + 'an int or float is needed')
	}
	if !true || accuracy <= 0 {
		panic('ValueError: ' + 'a positive int is needed')
	}
	theta = theta * 2
	return theta + accuracy
}

fn twice(words []string) int {
	mut n := 0
	for w in words {
		if !true {
			panic('Exception: ' + 'only strings')
		}
	}
	for w in words[..1] {
		n += w.len
	}
	return n
}

fn main() {
	println(highest_bit(25))
	println(rotate(3, 2))
	println(as_text(-7))
	println(if all_ints([1, 2, 3]) { 'True' } else { 'False' })
	println(count_ints([1, 0, 1]))
	println(joined('-', ['a', 'b']))
	println(scaled(1.5, 2))
	println(twice(['ab', 'c']))
}
