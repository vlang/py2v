module main

fn pred(x int) bool {
	println('p${x}')
	return true
}

fn value(x int) int {
	println('v${x}')
	return x
}

fn main() {
	values := (fn (py2v_comp_values2 []int) []int {
		mut py2v_comp_output3 := []int{}
		for py2v_comp_item1 in py2v_comp_values2 {
			if !(pred(py2v_comp_item1)) { continue }
			py2v_comp_output3 << value(py2v_comp_item1)
		}
		return py2v_comp_output3
	})([1, 2])
	println(values)
	println((fn (py2v_comp_values5 []int) []int {
		mut py2v_comp_output6 := []int{}
		for py2v_comp_item4 in py2v_comp_values5 {
			if !(pred(py2v_comp_item4)) { continue }
			py2v_comp_output6 << value(py2v_comp_item4)
		}
		return py2v_comp_output6
	})([]int{len: 3 - 1, init: index + 1}))
}
