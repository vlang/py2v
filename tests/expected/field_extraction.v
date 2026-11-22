module main

// Slots - Fields declared only through __slots__.
pub struct Slots {
pub mut:
	name_ string
	size  int
}

fn (mut self Slots) init(name_ string) {
	self.name_ = name_
	self.size = 0
}

fn (mut self Slots) bump(name_ string) string {
	self.size += 1
	return self.name_
}

pub fn py2v_new_slots(name_ string) Slots {
	mut py2v_instance := Slots{}
	py2v_instance.init(name_)
	return py2v_instance
}

pub struct Base {
pub mut:
	value string
}

fn (mut self Base) init(value string) {
	self.value = value
}

pub fn py2v_new_base(value string) Base {
	mut py2v_instance := Base{}
	py2v_instance.init(value)
	return py2v_instance
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

pub fn py2v_new_derived(value string) Derived {
	mut py2v_instance := Derived{}
	py2v_instance.init(value)
	return py2v_instance
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

pub fn py2v_new_late_assignment() LateAssignment {
	mut py2v_instance := LateAssignment{}
	py2v_instance.init()
	return py2v_instance
}

fn use() int {
	s := py2v_new_slots('a')
	d := py2v_new_derived('b')
	mut l := py2v_new_late_assignment()
	return int(s.size + l.add(1)) + py2v_text_length1(d.label())
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}
