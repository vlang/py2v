module main

fn from_tuple(values [2]int) []int {
	return py2v_range_unpack1(values).clone()
}

fn from_list(values []int) []int {
	return py2v_range_unpack1(values).clone()
}

fn bounds() []int {
	println('bounds')
	return [7, -2, -3]
}

@[inline]
fn py2v_range_bound1[T](value T) int {
	$if T is $int || T is bool {
		return int(value)
	} $else $if T is $sumtype {
		$for variant in T.variants {
			$if variant is $int || variant is bool {
				if value is variant {
					return int(value)
				}
			}
		}
		panic('TypeError: range needs integer bounds')
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
}

fn py2v_range_array1(start int, stop int, step int) []int {
	if step == 0 {
		panic('ValueError: range() arg 3 must not be zero')
	}
	mut values := []int{}
	for current := start; if step > 0 { current < stop } else { current > stop }; current += step {
		values << current
		if step > 0 {
			if u64(step) >= u64(stop) - u64(current) { break }
		} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
			break
		}
	}
	return values
}

fn py2v_range_unpack1[T](values T) []int {
	$if T is $array || T is $array_fixed {
		if values.len !in [1, 2, 3] {
			panic('TypeError: range expected 1 to 3 arguments')
		}
		mut args := [3]int{}
		for i, value in values { args[i] = py2v_range_bound1(value) }
		return match values.len {
			1 { py2v_range_array1(0, args[0], 1) }
			2 { py2v_range_array1(args[0], args[1], 1) }
			else { py2v_range_array1(args[0], args[1], args[2]) }
		}
	} $else {
		$compile_error('py2v_unsupported_range_unpack: range needs a native array')
	}
}

fn main() {
	println(from_tuple([-2, 4]))
	println(from_tuple([4, -2]))
	println(from_list([-2]))
	println(from_list([4, 8, 2]))
	println(py2v_range_unpack1(bounds()).clone())
	println(py2v_range_unpack1([2, 5]).clone())
}
