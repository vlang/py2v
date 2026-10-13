module main

// Registry - Uses __slots__, which must not become a struct field.
pub struct Registry {
pub mut:
	count_ int
}

fn (mut self Registry) init() {
	self.count_ = 0
}

fn (mut self Registry) bump(by_ int) int {
	self.count_ += by_
	return self.count_
}

pub struct Child {
	Registry
}

fn (mut self Child) bump(by_ int) int {
	return self.Registry.bump(by_)
}

fn locals_demo() int {
	first_ := 1
	second_ := 2
	total_ := first_ + second_
	throwaway_, kept_ := 3, 4
	return total_ + kept_
}
