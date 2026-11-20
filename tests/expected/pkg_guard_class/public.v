module py_pkg_guard_class

pub struct ColorBox {
}

pub fn (self ColorBox) value() int {
	return 2
}

pub fn read() int {
	return ColorBox{}.value()
}
