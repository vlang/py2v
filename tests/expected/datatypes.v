@[translated]
module main

pub struct IntListNonEmpty {
pub mut:
	first int
	rest IntList
}

pub struct IntList {
pub mut:
	NONE auto
	REST IntListNonEmpty
}
