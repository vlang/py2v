module main

fn report(items ?[]int, data ?map[string]int) {
	println((if items != none && items.len > 0 { items } else { []int{} }).len)
	println((if data != none && data.len > 0 { data } else { map[string]int{} }).len)
	if items != none && items.len > 0 {
		println('items')
	}
	if data != none && data.len > 0 {
		println('data')
	}
}

fn main() {
	report(none, none)
}
