module main

fn flags() bool {
	enabled := false
	count := 0
	ratio := 0.0
	label := ''
	items := []int{}
	table := map[string]int{}
	return enabled || count > 0 || ratio > 0 || label != '' || items.len > 0 || table.len > 0
}
