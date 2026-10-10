module main

// Registry - Uses __slots__, which must not become a struct field.
pub struct Registry {
pub mut:
	count int
}

fn (mut self Registry) init() {
	self.count = 0
}

fn (mut self Registry) bump(by int) int {
	self.count += by
	return self.count
}

pub struct Child {
	Registry
}

fn (mut self Child) bump(by int) int {
	return self.Registry.bump(by)
}

fn locals_demo() int {
	first := 1
	second := 2
	total := first + second
	throwaway, kept := 3, 4
	return total + kept
}
