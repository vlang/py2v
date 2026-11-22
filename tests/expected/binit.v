module main

fn bisect_right(data []int, item int) int {
	mut low := 0
	mut high := int(data.len)
	for low < high {
		middle := int(f64(low + high) / 2)
		if item < data[middle] {
			high = middle
		} else {
			low = middle + 1
		}
	}
	return low
}

fn bin_it(limits []int, data []int) []int {
	mut bins := [0]
	for x_ in limits {
		bins << 0
	}
	for d in data {
		mut py2v_container1 := &bins
		py2v_index2 := bisect_right(limits, d)
		py2v_old3 := (*py2v_container1)[if py2v_index2 < 0 {
			py2v_container1.len + py2v_index2
		} else {
			py2v_index2
		}]
		py2v_aug_result4 := py2v_integer_add1(py2v_old3, 1, 'binit.py:27', 'addition')
		(*py2v_container1)[if py2v_index2 < 0 {
			py2v_container1.len + py2v_index2
		} else {
			py2v_index2
		}] = py2v_aug_result4
	}
	return bins
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	limits := [23, 37, 43, 53, 67, 83]
	data := [
		95,
		21,
		94,
		12,
		99,
		4,
		70,
		75,
		83,
		93,
		52,
		80,
		57,
		5,
		53,
		86,
		65,
		17,
		92,
		83,
		71,
		61,
		54,
		58,
		47,
		16,
		8,
		9,
		32,
		84,
		7,
		87,
		46,
		19,
		30,
		37,
		96,
		6,
		98,
		40,
		79,
		97,
		45,
		64,
		60,
		29,
		49,
		36,
		43,
		55,
	]
	assert bin_it(limits, data) == [11, 4, 2, 6, 9, 5, 13]
	println('OK')
}
