module main

pub struct Box[I] {
pub mut:
	item &I
}

fn (mut self Box[I]) init(item I) {
	self.item = item
}

fn (self Box[I]) get() I {
	return self.item
}

pub struct Pair[K, V] {
pub mut:
	key   &K
	value &V
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

pub struct Holder[U, T] {
pub mut:
	inner &U
	other &T
}

fn (mut self Holder[U, T]) init(inner U, other T) {
	self.inner = inner
	self.other = other
}

fn (self Holder[U, T]) unwrap() U {
	return self.inner
}

fn main() {
	b := Box{
		item: 7
	}
	println(b.get())
	p := Pair{
		key:   'a'
		value: 1
	}
	println(p.first())
	println(p.second())
	h := Holder{
		inner: 'in'
		other: 3
	}
	println(h.unwrap())
}
