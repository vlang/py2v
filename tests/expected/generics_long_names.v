module main

pub struct Box[I] {
pub mut:
	item I
}

fn (mut self Box[I]) init(item I) {
	self.item = item
}

fn (self Box[I]) get() I {
	return self.item
}

pub fn py2v_new_box[I](item I) Box[I] {
	mut py2v_instance := Box[I]{}
	py2v_instance.init(item)
	return py2v_instance
}

pub struct Pair[K, V] {
pub mut:
	key   K
	value V
}

fn (mut self Pair[K, V]) init(key K, value V) {
	self.key = key
	self.value = value
}

fn (self Pair[K, V]) first() K {
	return self.key
}

fn (self Pair[K, V]) second() V {
	return self.value
}

pub fn py2v_new_pair[K, V](key K, value V) Pair[K, V] {
	mut py2v_instance := Pair[K, V]{}
	py2v_instance.init(key, value)
	return py2v_instance
}

pub struct Holder[U, T] {
pub mut:
	inner U
	other T
}

fn (mut self Holder[U, T]) init(inner U, other T) {
	self.inner = inner
	self.other = other
}

fn (self Holder[U, T]) unwrap() U {
	return self.inner
}

pub fn py2v_new_holder[U, T](inner U, other T) Holder[U, T] {
	mut py2v_instance := Holder[U, T]{}
	py2v_instance.init(inner, other)
	return py2v_instance
}

fn main() {
	b := py2v_new_box(7)
	println(b.get())
	p := py2v_new_pair('a', 1)
	println(p.first())
	println(p.second())
	h := py2v_new_holder('in', 3)
	println(h.unwrap())
}
