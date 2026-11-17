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
