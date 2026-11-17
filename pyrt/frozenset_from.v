module pyrt

// frozenset_from constructs an immutable set and preserves an existing one's identity.
pub fn frozenset_from(iterable Value) !Value {
	if iterable is &Set {
		if iterable.frozen {
			return iterable
		}
	}
	return frozenset_of(iter(iterable)!)!
}

// item_in preserves Python's left-to-right membership operand evaluation order.
pub fn item_in(item Value, container Value) !bool {
	return contains(container, item)!
}
