module pyrt

fn test_convert_boxing_and_unboxing() {
	check_convert_boxing_and_unboxing() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_convert_boxing_and_unboxing() ! {
	got_1 := from_int(7)
	// python: repr(7) == '7'
	assert repr(got_1) == '7'
	got_2 := from_float(1.5)
	// python: repr(1.5) == '1.5'
	assert repr(got_2) == '1.5'
	got_3 := from_str('é')
	// python: repr('é') == "'é'"
	assert repr(got_3) == '\'é\''
	got_4 := from_bool(true)
	// python: repr(True) == 'True'
	assert repr(got_4) == 'True'
	got_5 := from_strings(['a', 'é'])
	// python: repr(['a','é']) == "['a', 'é']"
	assert repr(got_5) == '[\'a\', \'é\']'
	got_6 := from_ints([1,2])
	// python: repr([1,2]) == '[1, 2]'
	assert repr(got_6) == '[1, 2]'
	got_7 := from_map({'a': Value(i64(1))})
	// python: repr({'a':1}) == "{'a': 1}"
	assert repr(got_7) == '{\'a\': 1}'
	got_8 := from_bytes([u8(0),u8(255)])
	// python: repr(b'\x00\xff') == "b'\\x00\\xff'"
	assert repr(got_8) == 'b\'\\x00\\xff\''
	got_9 := as_int(Value(i64(7)))!
	// python: (int(7)) == 7
	assert got_9 == 7
	got_10 := as_int(Value(true))!
	// python: (int(True)) == 1
	assert got_10 == 1
	got_11 := as_float(Value(i64(7)))!
	// python: (float(7)) == 7.0
	assert got_11 == 7.0
	got_12 := as_float(Value(1.5))!
	// python: (float(1.5)) == 1.5
	assert got_12 == 1.5
	got_13 := as_str(Value('é'))!
	// python: ('é') == 'é'
	assert got_13 == 'é'
	got_14 := as_bool(Value(false))!
	// python: (False) == False
	assert got_14 == false
	mut items := as_list(from_ints([1,2]))!
	items[0] = Value(i64(9))
	// python: exec_result("a=list([1,2]); a[0]=9", "repr(a)") == '[9, 2]' 
	assert repr(Value(new_list(items))) == '[9, 2]'
	strings := as_strings(from_strings(['a', 'é']))!
	// python: ['a','é'] == ['a','é']
	assert strings.len == 2 && strings[0] == 'a' && strings[1] == 'é'
	typed := &IntList{items: [3,4]}
	typed_items := as_list(Value(Sequence(typed)))!
	// python: repr([3,4]) == "[3, 4]"
	assert repr(Value(new_list(typed_items))) == '[3, 4]'
	mut source_bytes := [u8(1),u8(2)]
	boxed_bytes := from_bytes(source_bytes)
	source_bytes[0] = u8(9)
	mut extracted_bytes := as_bytes(boxed_bytes)!
	extracted_bytes[1] = u8(8)
	// python: exec_result("a=bytearray([1,2]); b=bytes(a); a[0]=9; c=bytearray(b); c[1]=8", "repr(b)") == "b'\\x01\\x02'" 
	assert repr(boxed_bytes) == 'b\'\\x01\\x02\''
}

fn test_convert_strict_unboxing_contracts() {
	check_convert_strict_unboxing_contracts() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_convert_strict_unboxing_contracts() ! {
	bad_18 := convert_test_error(fn () !Value {
		_ = as_int(Value('1'))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_18 == 'TypeError|expected int, got str'
	bad_19 := convert_test_error(fn () !Value {
		_ = as_float(Value('1'))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_19 == 'TypeError|expected float, got str'
	bad_20 := convert_test_error(fn () !Value {
		_ = as_str(Value(i64(1)))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_20 == 'TypeError|expected str, got int'
	bad_21 := convert_test_error(fn () !Value {
		_ = as_bool(Value(i64(1)))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_21 == 'TypeError|expected bool, got int'
	bad_22 := convert_test_error(fn () !Value {
		_ = as_list(Value(new_tuple([]Value{})))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_22 == 'TypeError|expected list, got tuple'
	bad_23 := convert_test_error(fn () !Value {
		_ = as_strings(from_ints([1]))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_23 == 'TypeError|expected str, got int'
	bad_24 := convert_test_error(fn () !Value {
		_ = as_bytes(Value('x'))!
		return none_
	})
	// runtime: strict interop unboxing; this is not the Python coercing constructor.
	assert bad_24 == 'TypeError|expected bytes, got str'
}


fn convert_test_error(callback fn () !Value) string {
	_ = callback() or {
		if err is PyError { return err.class_name + '|' + err.msg() }
		return 'VError|' + err.msg()
	}
	return '<no error>'
}
