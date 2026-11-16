module main

import arrays
import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn show(small map[string]int, big map[string]int, rank int) {
	mut py2v_comp1 := []bool{}
	for k, v_ in small {
		py2v_comp1 << big[k] >= v_
	}
	println(if py2v_comp1.all(it) { 'True' } else { 'False' })
	mut py2v_comp2 := []string{}
	for k, v_ in small {
		if v_ == rank {
			py2v_comp2 << k
		}
	}
	println(py2v_comp2)
	mut py2v_comp3 := map[string]int{}
	for k, v_ in small {
		py2v_comp3[k] = v_ * 2
	}
	println(py2v_comp3)
	println(arrays.sum(small.values().map(it)) or { 0 })
	println(big.keys().filter((it !in small)).map(it).sorted())
	mut py2v_comp4 := []bool{}
	for _, v_ in big {
		py2v_comp4 << v_ > 1
	}
	println(if py2v_comp4.any(it) { 'True' } else { 'False' })
	mut names := []string{}
	for k, v_ in big {
		if v_ > 0 && k != 'z' {
			names << k + v_.str()
		}
	}
	println('${names.len} ${names}')
	mut grid := []int{}
	for x in [1, 2] {
		for y in [10, 20] {
			grid << x * y
		}
	}
	println(grid)
	mut py2v_comp5 := []int{}
	for py2v_zipi1, n in [1, 2, 3] {
		w := [4, 5, 6][py2v_zipi1]
		py2v_comp5 << n * w
	}
	total := arrays.sum(py2v_comp5) or { 0 }
	println(total)
	mut py2v_comp6 := []string{}
	for k, v_ in small {
		py2v_comp6 << '${k}=${v_}'
	}
	println(py2v_comp6.join(', '))
}

fn main() {
	show(map[string]int{
		'a': 1
		'b': 2
	}, map[string]int{
		'a': 1
		'b': 3
		'c': 0
	}, 2)
}
