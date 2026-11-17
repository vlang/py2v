module pyrt

fn test_frozenset_from_preserves_identity_and_copies_mutable_sets() {
	mut source := new_set([Value(1), Value(2)]) or { panic(err) }
	frozen := frozenset_from(Value(source)) or { panic(err) }
	again := frozenset_from(frozen) or { panic(err) }
	assert object_identity(frozen) == object_identity(again)
	assert object_identity(frozen) != object_identity(Value(source))
	source.add(Value(3)) or { panic(err) }
	assert !(contains(frozen, Value(3)) or { panic(err) })
	assert contains(Value(source), Value(3)) or { panic(err) }
}

fn test_frozenset_from_iterates_and_preserves_python_errors() {
	value := frozenset_from(Value('αaα')) or { panic(err) }
	assert len_(value) or { panic(err) } == 2
	frozenset_from(Value(7)) or {
		assert caught(err, 'TypeError') != none
		return
	}
	assert false, 'an integer is not iterable'
}
