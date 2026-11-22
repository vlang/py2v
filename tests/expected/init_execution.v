module main

pub struct Box {
pub mut:
	total int
	label string
}

fn (mut self Box) init(a int, b int) {
	self.total = a + b
	self.label = 'box'
}

pub fn py2v_new_box_1(a int, b int) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(a, b)
	return py2v_instance
}

pub struct Defaulted {
pub mut:
	a     int
	b     int
	label string
}

fn (mut self Defaulted) init(a int, b int, label string) {
	self.a = a
	self.b = b
	self.label = label
}

pub fn py2v_new_defaulted(a int, b int, label string) Defaulted {
	mut py2v_instance := Defaulted{}
	py2v_instance.init(a, b, label)
	return py2v_instance
}

pub struct CallsMethod {
pub mut:
	value int
}

fn (mut self CallsMethod) init(amount int) {
	self.value = 0
	self.add(amount)
}

fn (mut self CallsMethod) add(amount int) {
	self.value += amount
}

pub fn py2v_new_calls_method(amount int) CallsMethod {
	mut py2v_instance := CallsMethod{}
	py2v_instance.init(amount)
	return py2v_instance
}

pub struct ConstructsAnother {
pub mut:
	total int
}

fn (mut self ConstructsAnother) init(a int, b int) {
	inner := py2v_new_box_1(a, b)
	self.total = inner.total
}

pub fn py2v_new_constructs_another(a int, b int) ConstructsAnother {
	mut py2v_instance := ConstructsAnother{}
	py2v_instance.init(a, b)
	return py2v_instance
}

pub struct Zero {
pub mut:
	value int
}

fn (mut self Zero) init() {
	self.value = 7
}

pub fn py2v_new_zero() Zero {
	mut py2v_instance := Zero{}
	py2v_instance.init()
	return py2v_instance
}

pub struct Base {
pub mut:
	value int
}

fn (mut self Base) init(value int) {
	self.value = value
}

pub fn py2v_new_base(value int) Base {
	mut py2v_instance := Base{}
	py2v_instance.init(value)
	return py2v_instance
}

pub struct Child {
	Base
pub mut:
	extra int
}

fn (mut self Child) init(value int, extra int) {
	self.Base.init(value)
	self.extra = extra
}

pub fn py2v_new_child(value int, extra int) Child {
	mut py2v_instance := Child{}
	py2v_instance.init(value, extra)
	return py2v_instance
}

pub struct PlainChild {
	Base
}

pub struct Plain {
pub mut:
	value int = 17
}

fn py2v_new_box() int {
	return 99
}

fn mark(value int) int {
	println(value)
	return value
}

fn ordered_calls() {
	start := 4
	positional := (fn [start] () Defaulted {
		py2v_init_arg1 := mark(start)
		py2v_init_arg2 := mark(start + 1)
		return py2v_new_defaulted(py2v_init_arg1, py2v_init_arg2, 'positional')
	})()
	println('${positional.a} ${positional.b} ${positional.label}')
	keyword := (fn [start] () Defaulted {
		py2v_init_arg3 := mark(start + 2)
		py2v_init_arg4 := mark(start + 3)
		return py2v_new_defaulted(py2v_init_arg4, py2v_init_arg3, 'keyword')
	})()
	println('${keyword.a} ${keyword.b} ${keyword.label}')
}

fn main() {
	b := py2v_new_box_1(2, 3)
	println('${b.total} ${b.label}')
	d := py2v_new_defaulted(2, 7, 'default')
	println('${d.a} ${d.b} ${d.label}')
	k := py2v_new_defaulted(3, 8, 'named')
	println('${k.a} ${k.b} ${k.label}')
	m := py2v_new_calls_method(9)
	println(m.value)
	n := py2v_new_constructs_another(4, 5)
	println(n.total)
	z := py2v_new_zero()
	println(z.value)
	c := py2v_new_child(10, 2)
	println('${c.value} ${c.extra}')
	inherited := PlainChild{
		Base: Base{ value: 11 }
	}
	println(inherited.value)
	p := Plain{}
	println(p.value)
	println(py2v_new_box())
	ordered_calls()
}
