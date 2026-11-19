module py_pkg_module_string_product

pub const files = ['a', 'b']
pub const ranks = ['1', '2']
pub const squares = (fn () []string {
	mut result := []string{}
	for rank in ranks {
		for file in files {
			result << file + rank
		}
	}
	return result
})()

pub fn total() string {
	return squares.join(' ')
}
