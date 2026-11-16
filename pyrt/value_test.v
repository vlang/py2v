module pyrt

fn test_value_truth_names_lengths_iteration() {
	check_value_truth_names_lengths_iteration() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_value_truth_names_lengths_iteration() ! {
	got_1 := type_name(none_)
	// python: (type(None).__name__) == 'NoneType'
	assert got_1 == 'NoneType'
	got_2 := truth(none_)
	// python: (bool(None)) == False
	assert got_2 == false
	got_3 := type_name(Value(false))
	// python: (type(False).__name__) == 'bool'
	assert got_3 == 'bool'
	got_4 := truth(Value(false))
	// python: (bool(False)) == False
	assert got_4 == false
	got_5 := type_name(Value(true))
	// python: (type(True).__name__) == 'bool'
	assert got_5 == 'bool'
	got_6 := truth(Value(true))
	// python: (bool(True)) == True
	assert got_6 == true
	got_7 := type_name(Value(i64(0)))
	// python: (type(0).__name__) == 'int'
	assert got_7 == 'int'
	got_8 := truth(Value(i64(0)))
	// python: (bool(0)) == False
	assert got_8 == false
	got_9 := type_name(Value(i64(1)))
	// python: (type(1).__name__) == 'int'
	assert got_9 == 'int'
	got_10 := truth(Value(i64(1)))
	// python: (bool(1)) == True
	assert got_10 == true
	got_11 := type_name(Value(0.0))
	// python: (type(0.0).__name__) == 'float'
	assert got_11 == 'float'
	got_12 := truth(Value(0.0))
	// python: (bool(0.0)) == False
	assert got_12 == false
	got_13 := type_name(Value(-0.0))
	// python: (type(-0.0).__name__) == 'float'
	assert got_13 == 'float'
	got_14 := truth(Value(-0.0))
	// python: (bool(-0.0)) == False
	assert got_14 == false
	got_15 := type_name(Value(1.5))
	// python: (type(1.5).__name__) == 'float'
	assert got_15 == 'float'
	got_16 := truth(Value(1.5))
	// python: (bool(1.5)) == True
	assert got_16 == true
	got_17 := type_name(Value(''))
	// python: (type('').__name__) == 'str'
	assert got_17 == 'str'
	got_18 := truth(Value(''))
	// python: (bool('')) == False
	assert got_18 == false
	got_19 := len_(Value(''))!
	// python: (len('')) == 0
	assert got_19 == 0
	got_20 := Value(new_list(iter(Value(''))!))
	// python: repr(list('')) == '[]'
	assert repr(got_20) == '[]'
	got_21 := type_name(Value('é🙂'))
	// python: (type('é🙂').__name__) == 'str'
	assert got_21 == 'str'
	got_22 := truth(Value('é🙂'))
	// python: (bool('é🙂')) == True
	assert got_22 == true
	got_23 := len_(Value('é🙂'))!
	// python: (len('é🙂')) == 2
	assert got_23 == 2
	got_24 := Value(new_list(iter(Value('é🙂'))!))
	// python: repr(list('é🙂')) == "['é', '🙂']"
	assert repr(got_24) == '[\'é\', \'🙂\']'
	got_25 := type_name(Value([]u8{}))
	// python: (type(b'').__name__) == 'bytes'
	assert got_25 == 'bytes'
	got_26 := truth(Value([]u8{}))
	// python: (bool(b'')) == False
	assert got_26 == false
	got_27 := len_(Value([]u8{}))!
	// python: (len(b'')) == 0
	assert got_27 == 0
	got_28 := Value(new_list(iter(Value([]u8{}))!))
	// python: repr(list(b'')) == '[]'
	assert repr(got_28) == '[]'
	got_29 := type_name(Value([u8(255)]))
	// python: (type(b'\xff').__name__) == 'bytes'
	assert got_29 == 'bytes'
	got_30 := truth(Value([u8(255)]))
	// python: (bool(b'\xff')) == True
	assert got_30 == true
	got_31 := len_(Value([u8(255)]))!
	// python: (len(b'\xff')) == 1
	assert got_31 == 1
	got_32 := Value(new_list(iter(Value([u8(255)]))!))
	// python: repr(list(b'\xff')) == '[255]'
	assert repr(got_32) == '[255]'
	got_33 := type_name(Value(new_list([]Value{})))
	// python: (type([]).__name__) == 'list'
	assert got_33 == 'list'
	got_34 := truth(Value(new_list([]Value{})))
	// python: (bool([])) == False
	assert got_34 == false
	got_35 := len_(Value(new_list([]Value{})))!
	// python: (len([])) == 0
	assert got_35 == 0
	got_36 := Value(new_list(iter(Value(new_list([]Value{})))!))
	// python: repr(list([])) == '[]'
	assert repr(got_36) == '[]'
	got_37 := type_name(Value(new_list([Value(i64(1))])))
	// python: (type([1]).__name__) == 'list'
	assert got_37 == 'list'
	got_38 := truth(Value(new_list([Value(i64(1))])))
	// python: (bool([1])) == True
	assert got_38 == true
	got_39 := len_(Value(new_list([Value(i64(1))])))!
	// python: (len([1])) == 1
	assert got_39 == 1
	got_40 := Value(new_list(iter(Value(new_list([Value(i64(1))])))!))
	// python: repr(list([1])) == '[1]'
	assert repr(got_40) == '[1]'
	got_41 := type_name(Value(new_tuple([]Value{})))
	// python: (type(()).__name__) == 'tuple'
	assert got_41 == 'tuple'
	got_42 := truth(Value(new_tuple([]Value{})))
	// python: (bool(())) == False
	assert got_42 == false
	got_43 := len_(Value(new_tuple([]Value{})))!
	// python: (len(())) == 0
	assert got_43 == 0
	got_44 := Value(new_list(iter(Value(new_tuple([]Value{})))!))
	// python: repr(list(())) == '[]'
	assert repr(got_44) == '[]'
	got_45 := type_name(Value(new_tuple([Value(i64(1))])))
	// python: (type((1,)).__name__) == 'tuple'
	assert got_45 == 'tuple'
	got_46 := truth(Value(new_tuple([Value(i64(1))])))
	// python: (bool((1,))) == True
	assert got_46 == true
	got_47 := len_(Value(new_tuple([Value(i64(1))])))!
	// python: (len((1,))) == 1
	assert got_47 == 1
	got_48 := Value(new_list(iter(Value(new_tuple([Value(i64(1))])))!))
	// python: repr(list((1,))) == '[1]'
	assert repr(got_48) == '[1]'
	got_49 := type_name(value_test_dict([]Value{}, []Value{})!)
	// python: (type({}).__name__) == 'dict'
	assert got_49 == 'dict'
	got_50 := truth(value_test_dict([]Value{}, []Value{})!)
	// python: (bool({})) == False
	assert got_50 == false
	got_51 := len_(value_test_dict([]Value{}, []Value{})!)!
	// python: (len({})) == 0
	assert got_51 == 0
	got_52 := Value(new_list(iter(value_test_dict([]Value{}, []Value{})!)!))
	// python: repr(list({})) == '[]'
	assert repr(got_52) == '[]'
	got_53 := type_name(value_test_dict([Value('x')], [Value(i64(1))])!)
	// python: (type({'x': 1}).__name__) == 'dict'
	assert got_53 == 'dict'
	got_54 := truth(value_test_dict([Value('x')], [Value(i64(1))])!)
	// python: (bool({'x': 1})) == True
	assert got_54 == true
	got_55 := len_(value_test_dict([Value('x')], [Value(i64(1))])!)!
	// python: (len({'x': 1})) == 1
	assert got_55 == 1
	got_56 := Value(new_list(iter(value_test_dict([Value('x')], [Value(i64(1))])!)!))
	// python: repr(list({'x': 1})) == "['x']"
	assert repr(got_56) == '[\'x\']'
	got_57 := type_name(Value(new_set([]Value{})!))
	// python: (type(set()).__name__) == 'set'
	assert got_57 == 'set'
	got_58 := truth(Value(new_set([]Value{})!))
	// python: (bool(set())) == False
	assert got_58 == false
	got_59 := len_(Value(new_set([]Value{})!))!
	// python: (len(set())) == 0
	assert got_59 == 0
	got_60 := Value(new_list(iter(Value(new_set([]Value{})!))!))
	// python: repr(list(set())) == '[]'
	assert repr(got_60) == '[]'
	got_61 := type_name(Value(new_set([Value(i64(1))])!))
	// python: (type({1}).__name__) == 'set'
	assert got_61 == 'set'
	got_62 := truth(Value(new_set([Value(i64(1))])!))
	// python: (bool({1})) == True
	assert got_62 == true
	got_63 := len_(Value(new_set([Value(i64(1))])!))!
	// python: (len({1})) == 1
	assert got_63 == 1
	got_64 := Value(new_list(iter(Value(new_set([Value(i64(1))])!))!))
	// python: repr(list({1})) == '[1]'
	assert repr(got_64) == '[1]'
	got_65 := truth(Value(infinity() - infinity()))
	// python: (bool(float('nan'))) == True
	assert got_65 == true
}

fn test_value_constructors_and_aliases() {
	check_value_constructors_and_aliases() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_value_constructors_and_aliases() ! {
	mut source := [Value(i64(1))]
	l := new_list(source)
	tu := new_tuple(source)
	source[0] = Value(i64(9))
	// python: exec_result("a=[1]; b=list(a); a[0]=9", "repr(b)") == '[1]' 
	assert repr(Value(l)) == '[1]'
	// python: exec_result("a=[1]; b=tuple(a); a[0]=9", "repr(b)") == '(1,)' 
	assert repr(Value(tu)) == '(1,)'
	s := new_set([Value(i64(1)), Value(true), Value(1.0)])!
	got_68 := len_(Value(s))!
	// python: (len({1,True,1.0})) == 1
	assert got_68 == 1
	s.add(Value(i64(2)))!
	s.add(Value(i64(2)))!
	s.discard(Value(true))!
	s.discard(Value(i64(9)))!
	// python: exec_result("s={1}; s.add(2); s.add(2); s.discard(True); s.discard(9)", "repr(s)") == '{2}' 
	assert repr(Value(s)) == '{2}'
}

fn test_value_typed_sequence() {
	check_value_typed_sequence() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_value_typed_sequence() ! {
	mut typed := &IntList{items: [1, 2, 3]}
	boxed := Value(Sequence(typed))
	setitem(boxed, Value(i64(-1)), Value(i64(7)))!
	typed.items[0] = 5
	// python: exec_result("a=[1,2,3]; b=a; b[-1]=7; a[0]=5", "repr(b)") == '[5, 2, 7]' 
	assert repr(boxed) == '[5, 2, 7]'
	got_71 := typed.len()
	// python: (len([5,2,7])) == 3
	assert got_71 == 3
	got_72 := typed.get(-1)!
	// python: repr([5,2,7][-1]) == '7'
	assert repr(got_72) == '7'
	typed.set(1, Value(i64(4)))!
	// python: exec_result("a=[5,2,7]; a[1]=4", "repr(a)") == '[5, 4, 7]' 
	assert repr(boxed) == '[5, 4, 7]'
	delitem(boxed, Value(i64(-1)))!
	// python: exec_result("a=[5,4,7]; del a[-1]", "repr(a)") == '[5, 4]' 
	assert repr(boxed) == '[5, 4]'
	typed.delete(0)!
	// python: exec_result("a=[5,4]; del a[0]", "repr(a)") == '[4]' 
	assert repr(boxed) == '[4]'
	got_76 := eq(boxed, Value(new_list([Value(i64(4))])))
	// python: ([4] == [4]) == True
	assert got_76 == true
	// runtime: one stable nonzero identity token for this typed object.
	assert typed.pyrt_identity() == typed.pyrt_identity()
	got_78 := getslice(boxed, none, none, -1)!
	// python: repr([4][::-1]) == '[4]'
	assert repr(got_78) == '[4]'
	got_79 := add(boxed, Value(new_list([Value(i64(5))])))!
	// python: repr([4]+[5]) == '[4, 5]'
	assert repr(got_79) == '[4, 5]'
}

fn test_value_instances_and_functions() {
	check_value_instances_and_functions() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_value_instances_and_functions() ! {
	mut object := new_object('Example')
	boxed := Value(Instance(object))
	setattr(boxed, 'x', Value(i64(7)))!
	got_80 := object.class_name()
	// python: exec_result("class Example: pass\no=Example()", "type(o).__name__") == 'Example'
	assert got_80 == 'Example'
	got_81 := getattr(boxed, 'x')!
	// python: repr(exec_result("class Example: pass\no=Example(); o.x=7", "o.x")) == '7'
	assert repr(got_81) == '7'
	got_82 := object.getattr('x')!
	// python: repr(exec_result("class Example: pass\no=Example(); o.x=7", "o.x")) == '7'
	assert repr(got_82) == '7'
	object.setattr('x', Value(i64(9)))!
	got_83 := getattr(boxed, 'x')!
	// python: repr(exec_result("class Example: pass\no=Example(); o.x=9", "o.x")) == '9'
	assert repr(got_83) == '9'
	got_84 := truth(boxed)
	// python: (bool(object())) == True
	assert got_84 == true
	got_85 := eq(boxed, boxed)
	// python: ((lambda o: o == o)(object())) == True
	assert got_85 == true
	got_86 := eq(boxed, Value(Instance(new_object('Example'))))
	// python: (object() == object()) == False
	assert got_86 == false
	// runtime: the Instance identity remains stable.
	assert object.pyrt_identity() == object.pyrt_identity()
	f := function('sum_two', fn (args []Value) !Value { return add(args[0], args[1])! })
	got_88 := call(f, [Value(i64(2)), Value(i64(3))])!
	// python: repr((lambda a,b:a+b)(2,3)) == '5'
	assert repr(got_88) == '5'
	got_89 := getattr(f, '__name__')!
	// python: repr(exec_result("def sum_two(a,b): return a+b", "sum_two.__name__")) == "'sum_two'"
	assert repr(got_89) == '\'sum_two\''
	got_90 := eq(f, f)
	// python: ((lambda f:f==f)(lambda:None)) == True
	assert got_90 == true
	g := function('sum_two', fn (args []Value) !Value { return add(args[0], args[1])! })
	got_91 := eq(f, g)
	// python: ((lambda:None) == (lambda:None)) == False
	assert got_91 == false
	cell := &ValueTestCell{}
	counter := function('counter', fn [cell] (args []Value) !Value {
		_ = args
		unsafe { cell.value = cell.value + 1 }
		return Value(cell.value)
	})
	got_92 := call(counter, []Value{})!
	// python: repr(exec_result('def make_counter():\n    n = 0\n    def inc():\n        nonlocal n\n        n += 1\n        return n\n    return inc\nc = make_counter()', "c()")) == '1'
	assert repr(got_92) == '1'
	got_93 := call(counter, []Value{})!
	// python: repr(exec_result('def make_counter():\n    n = 0\n    def inc():\n        nonlocal n\n        n += 1\n        return n\n    return inc\nc = make_counter()\nc()', "c()")) == '2'
	assert repr(got_93) == '2'
}

fn test_value_value_errors() {
	check_value_value_errors() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_value_value_errors() ! {
	got_94 := value_test_error(fn () !Value {
		return call(Value(i64(1)), []Value{})!
	})
	// python: error_text(lambda: (1)()) == "TypeError|'int' object is not callable"
	assert got_94 == 'TypeError|\'int\' object is not callable'
	got_95 := value_test_error(fn () !Value {
		return getattr(Value(i64(1)), 'x')!
	})
	// python: error_text(lambda: getattr(1,'x')) == "AttributeError|'int' object has no attribute 'x'"
	assert got_95 == 'AttributeError|\'int\' object has no attribute \'x\''
	got_96 := value_test_error(fn () !Value {
		setattr(Value(i64(1)), 'x', none_)!
	return none_
	})
	// python: error_text(lambda: setattr(1,'x',None)) == "AttributeError|'int' object has no attribute 'x' and no __dict__ for setting new attributes"
	assert got_96 == 'AttributeError|\'int\' object has no attribute \'x\' and no __dict__ for setting new attributes'
	got_97 := value_test_error(fn () !Value {
		return Value(new_list(iter(Value(i64(1)))!))
	})
	// python: error_text(lambda: iter(1)) == "TypeError|'int' object is not iterable"
	assert got_97 == 'TypeError|\'int\' object is not iterable'
	got_98 := value_test_error(fn () !Value {
		return getattr(Value(Instance(new_object('Example'))), 'missing')!
	})
	// python: error_text(lambda: exec_result("class Example: pass\no=Example()", "o.missing")) == "AttributeError|'Example' object has no attribute 'missing'"
	assert got_98 == 'AttributeError|\'Example\' object has no attribute \'missing\''
}

struct ValueTestCell {
mut:
	value i64
}

fn value_test_error(callback fn () !Value) string {
	_ = callback() or {
		if err is PyError { return err.class_name + '|' + err.msg() }
		return 'VError|' + err.msg()
	}
	return '<no error>'
}
fn value_test_dict(keys []Value, values []Value) !Value {
	d := Value(new_dict())
	for i, key in keys { setitem(d, key, values[i])! }
	return d
}
