module pyrt

fn test_box_runtime_handles_keep_their_identity() {
	object := new_object('Record')
	value := box(object)
	setattr(value, 'name', Value('ada')) or { panic(err) }
	assert (object.getattr('name') or { panic(err) }) == Value('ada')
	assert object_identity(value) != 0
	assert object_identity(value) == object_identity(Value(Instance(object)))
	list := new_list([Value(1)])
	assert object_identity(box(list)) != 0
	assert object_identity(box(list)) == object_identity(Value(list))
	dict := new_dict()
	assert object_identity(box(dict)) != 0
	assert object_identity(box(dict)) == object_identity(Value(dict))
	set := new_set([Value(1)]) or { panic(err) }
	assert object_identity(box(set)) != 0
	assert object_identity(box(set)) == object_identity(Value(set))
	tuple := new_tuple([Value(1)])
	assert object_identity(box(tuple)) != 0
	assert object_identity(box(tuple)) == object_identity(Value(tuple))
	assert box(NoneType{}) is NoneType
}

fn test_box_typed_sequence_keeps_mutation_and_identity() {
	sequence := &IntList{ items: [1, 2] }
	value := box(sequence)
	setitem(value, Value(0), Value(7)) or { panic(err) }
	assert sequence.items == [7, 2]
	assert object_identity(value) != 0
	assert object_identity(value) == object_identity(Value(Sequence(sequence)))
}

fn test_box_bytes_are_bytes_and_snapshot_native_storage() {
	mut native := [u8(65), 66]
	value := box(native)
	native[0] = 90
	assert type_name(value) == 'bytes'
	assert (getitem(value, Value(0)) or { panic(err) }) == Value(i64(65))
	assert str(value) == "b'AB'"
}

fn test_box_function_keeps_its_callback() {
	f := Function{ name: 'echo', call: fn (args []Value) !Value { return args[0] } }
	assert (call(box(f), [Value('ok')]) or { panic(err) }) == Value('ok')
}

fn test_box_optional_scalars_distinguishes_absence_from_false_values() {
	assert box(?string(none)) is NoneType
	assert box(?string('')) == Value('')
	assert box(?string('present')) == Value('present')
	assert box(?int(none)) is NoneType
	assert box(?int(0)) == Value(i64(0))
	assert box(?i64(7)) == Value(i64(7))
	assert box(?f64(0.0)) == Value(0.0)
	assert box(?bool(false)) == Value(false)
	assert box(?Value(none)) is NoneType
	assert box(?Value(Value('present'))) == Value('present')
}

fn test_box_optional_handles_keep_identity() {
	list := new_list([Value(1)])
	assert box(?&List(none)) is NoneType
	assert object_identity(box(?&List(list))) != 0
	assert object_identity(box(?&List(list))) == object_identity(Value(list))
	object := new_object('Record')
	assert object_identity(box(?Instance(Instance(object)))) != 0
	assert object_identity(box(?Instance(Instance(object)))) == object_identity(box(object))
	sequence := &IntList{ items: [1] }
	assert object_identity(box(?Sequence(Sequence(sequence)))) != 0
	assert object_identity(box(?Sequence(Sequence(sequence)))) == object_identity(box(sequence))
	assert box(?[]u8([u8(65)])) == Value([u8(65)])
}

fn test_none_singleton_test_does_not_confuse_false_values() {
	assert is_none(none_)
	for value in [Value(false), Value(i64(0)), Value(''), Value(new_list([]Value{}))] {
		assert !is_none(value)
	}
}

fn test_box_shared_native_list_keeps_source_and_runtime_mutation() {
	mut source := list_ref([1])
	first := box(source)
	second := box(source)
	source.items << 2
	assert length(first) == 2
	assert length(second) == 2
	assert object_identity(first) == object_identity(second)
	invoke(first, 'append', box(3))
	set_index(second, box(0), box(9))
	assert source.items == [9, 2, 3]
	assert str(first) == '[9, 2, 3]'
}

fn test_box_nested_shared_native_lists_keep_element_identity() {
	mut row := list_ref([1])
	outer := list_ref([row])
	boxed := box(outer)
	copy := invoke(boxed, 'copy')
	row.items << 2
	assert str(copy) == '[[1, 2]]'
	invoke(boxed, 'append', box(row))
	assert outer.items.len == 2
	invoke(item_at(boxed, box(1)), 'append', box(3))
	assert row.items == [1, 2, 3]
}

fn test_shared_native_integer_list_refuses_lossy_runtime_writes() {
	mut source := list_ref([1])
	for value in [i64(-2147483649), i64(2147483648)] {
		if _ := source.list_method('append', [box(value)]) {
			assert false, 'an out-of-range integer must not be truncated'
		} else {
			assert err.msg().contains('py2v: runtime integer does not fit')
		}
		assert source.items == [1]
	}
	if _ := source.list_method('append', [box('x')]) {
		assert false, 'an incompatible runtime element must not be coerced'
	} else {
		assert err.msg().contains('py2v: shared native list cannot hold runtime str')
	}
	assert source.items == [1]
	for value in [i64(-2147483648), i64(2147483647)] {
		source.list_method('append', [box(value)]) or { panic(err) }
	}
	assert source.items == [1, -2147483648, 2147483647]
}
