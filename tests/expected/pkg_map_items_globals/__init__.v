module py_pkg_map_items_globals

pub const cutoff = 2
pub const weights = {
	'low':  1
	'high': 3
}

const target_selected = (fn (py2v_comp_map1 map[string]int) []string {
	mut py2v_comp_result2 := []string{}
	for py2v_comp_key3, py2v_comp_value4 in py2v_comp_map1 {
		if !(py2v_comp_value4 >= cutoff) { continue }
		py2v_comp_result2 << py2v_comp_key3
	}
	return py2v_comp_result2
})(weights)

pub struct Target {
}

pub fn tuple_labels(positions map[[2]int]string, enabled bool) string {
	labels := if !enabled {
		['disabled']
	} else {
		(fn (py2v_comp_map5 map[[2]int]string) []string {
			mut py2v_comp_result6 := []string{}
			for py2v_comp_key7, py2v_comp_value8 in py2v_comp_map5 {
				if !(py2v_comp_key7[1] > 1) { continue }
				py2v_comp_result6 << py2v_comp_value8
			}
			return py2v_comp_result6
		})(positions)
	}
	return labels.join(':')
}

pub fn total() string {
	positions := map[[2]int]string{
		[0, 1]: 'low'
		[0, 2]: 'high'
	}
	return target_selected.join(':') + ',' + tuple_labels(positions, true)
}
