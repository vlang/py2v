module main

type Any = bool | int | i64 | f64 | string | []u8

// Slots - Fields declared only through __slots__.
pub struct Slots {
pub mut:
	name_ Any
	size  Any
}

fn (mut self Slots) init(name_ string) {
	self.name_ = name_
	self.size = 0
}

fn (mut self Slots) bump(name_ string) string {
	self.size += 1
	return self.name_
}

pub struct Base {
pub mut:
	value string
}

fn (mut self Base) init(value string) {
	self.value = value
}

// Derived - Declares no fields of its own; the constructor delegates upward.
pub struct Derived {
	Base
}

fn (mut self Derived) init(value string) {
	self.Base.init(value)
}

fn (self Derived) label() string {
	return self.value
}

// LateAssignment - A slot declared before the annotation that types it.
pub struct LateAssignment {
pub mut:
	count int
}

fn (mut self LateAssignment) init() {
	self.count = 0
}

fn (mut self LateAssignment) add(by int) int {
	self.count += by
	return self.count
}

fn use() int {
	s := Slots{
		name_: 'a'
	}
	d := Derived{
		Base: Base{ value: 'b' }
	}
	l := LateAssignment{}
	return s.size + l.add(1) + d.label().len
}
