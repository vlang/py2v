@[translated]
module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct IntListNonEmpty {
pub mut:
	first int
	rest  &IntList
}

pub struct IntList {
pub mut:
	NONE Any
	REST &IntListNonEmpty
}
