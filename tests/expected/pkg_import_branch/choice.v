module py_pkg_import_branch

pub struct Label {
}

pub fn (self Label) text() string {
	return 'present'
}

pub fn pick() int {
	return value()
}

pub fn total() string {
	return (pick() + value()).str() + ' ' + Label{}.text()
}
