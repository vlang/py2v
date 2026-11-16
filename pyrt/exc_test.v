module pyrt

fn test_exc_messages_and_args() {
	check_exc_messages_and_args() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_exc_messages_and_args() ! {
	got_1 := exception('ValueError', []Value{}).msg()
	// python: (str(ValueError())) == ''
	assert got_1 == ''
	got_2 := exception('ValueError', [Value('bad')]).msg()
	// python: (str(ValueError('bad'))) == 'bad'
	assert got_2 == 'bad'
	got_3 := exception('ValueError', [Value('a'), Value(i64(2))]).msg()
	// python: (str(ValueError('a', 2))) == "('a', 2)"
	assert got_3 == '(\'a\', 2)'
	got_4 := exception('KeyError', [Value('x')]).msg()
	// python: (str(KeyError('x'))) == "'x'"
	assert got_4 == '\'x\''
	got_5 := exception('KeyError', [Value(i64(1))]).msg()
	// python: (str(KeyError(1))) == '1'
	assert got_5 == '1'
	got_6 := exception('KeyError', [Value(new_tuple([Value(i64(1)), Value('x')]))]).msg()
	// python: (str(KeyError((1, 'x')))) == "(1, 'x')"
	assert got_6 == '(1, \'x\')'
	got_7 := exception('KeyError', []Value{}).msg()
	// python: (str(KeyError())) == ''
	assert got_7 == ''
	got_8 := exception('KeyError', [Value('a'), Value('b')]).msg()
	// python: (str(KeyError('a', 'b'))) == "('a', 'b')"
	assert got_8 == '(\'a\', \'b\')'
	got_9 := exception('OSError', [Value('bad')]).msg()
	// python: (str(OSError('bad'))) == 'bad'
	assert got_9 == 'bad'
	got_10 := raise('ValueError', 'bad').msg()
	// python: (str(ValueError('bad'))) == 'bad'
	assert got_10 == 'bad'
	got_11 := raise('KeyError', 'x').msg()
	// python: (str(KeyError('x'))) == "'x'"
	assert got_11 == '\'x\''
	got_12 := key_error(Value('x')).msg()
	// python: (str(KeyError('x'))) == "'x'"
	assert got_12 == '\'x\''
	got_13 := key_error(Value(i64(1))).msg()
	// python: (str(KeyError(1))) == '1'
	assert got_13 == '1'
}

fn test_exc_builtin_hierarchy() {
	check_exc_builtin_hierarchy() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_exc_builtin_hierarchy() ! {
	e_13 := raise('BaseException', 'x')
	mut caught_13 := false
	if matched := caught(e_13, 'BaseException') {
		_ = matched
		caught_13 = true
	}
	// python: issubclass(BaseException, BaseException) == True
	assert caught_13 == true
	mut caught_14 := false
	if matched := caught(e_13, 'Exception') {
		_ = matched
		caught_14 = true
	}
	// python: issubclass(BaseException, Exception) == False
	assert caught_14 == false
	e_15 := raise('Exception', 'x')
	mut caught_15 := false
	if matched := caught(e_15, 'BaseException') {
		_ = matched
		caught_15 = true
	}
	// python: issubclass(Exception, BaseException) == True
	assert caught_15 == true
	mut caught_16 := false
	if matched := caught(e_15, 'Exception') {
		_ = matched
		caught_16 = true
	}
	// python: issubclass(Exception, Exception) == True
	assert caught_16 == true
	e_17 := raise('ArithmeticError', 'x')
	mut caught_17 := false
	if matched := caught(e_17, 'BaseException') {
		_ = matched
		caught_17 = true
	}
	// python: issubclass(ArithmeticError, BaseException) == True
	assert caught_17 == true
	mut caught_18 := false
	if matched := caught(e_17, 'Exception') {
		_ = matched
		caught_18 = true
	}
	// python: issubclass(ArithmeticError, Exception) == True
	assert caught_18 == true
	e_19 := raise('ZeroDivisionError', 'x')
	mut caught_19 := false
	if matched := caught(e_19, 'BaseException') {
		_ = matched
		caught_19 = true
	}
	// python: issubclass(ZeroDivisionError, BaseException) == True
	assert caught_19 == true
	mut caught_20 := false
	if matched := caught(e_19, 'Exception') {
		_ = matched
		caught_20 = true
	}
	// python: issubclass(ZeroDivisionError, Exception) == True
	assert caught_20 == true
	e_21 := raise('OverflowError', 'x')
	mut caught_21 := false
	if matched := caught(e_21, 'BaseException') {
		_ = matched
		caught_21 = true
	}
	// python: issubclass(OverflowError, BaseException) == True
	assert caught_21 == true
	mut caught_22 := false
	if matched := caught(e_21, 'Exception') {
		_ = matched
		caught_22 = true
	}
	// python: issubclass(OverflowError, Exception) == True
	assert caught_22 == true
	e_23 := raise('LookupError', 'x')
	mut caught_23 := false
	if matched := caught(e_23, 'BaseException') {
		_ = matched
		caught_23 = true
	}
	// python: issubclass(LookupError, BaseException) == True
	assert caught_23 == true
	mut caught_24 := false
	if matched := caught(e_23, 'Exception') {
		_ = matched
		caught_24 = true
	}
	// python: issubclass(LookupError, Exception) == True
	assert caught_24 == true
	e_25 := raise('KeyError', 'x')
	mut caught_25 := false
	if matched := caught(e_25, 'BaseException') {
		_ = matched
		caught_25 = true
	}
	// python: issubclass(KeyError, BaseException) == True
	assert caught_25 == true
	mut caught_26 := false
	if matched := caught(e_25, 'Exception') {
		_ = matched
		caught_26 = true
	}
	// python: issubclass(KeyError, Exception) == True
	assert caught_26 == true
	e_27 := raise('IndexError', 'x')
	mut caught_27 := false
	if matched := caught(e_27, 'BaseException') {
		_ = matched
		caught_27 = true
	}
	// python: issubclass(IndexError, BaseException) == True
	assert caught_27 == true
	mut caught_28 := false
	if matched := caught(e_27, 'Exception') {
		_ = matched
		caught_28 = true
	}
	// python: issubclass(IndexError, Exception) == True
	assert caught_28 == true
	e_29 := raise('TypeError', 'x')
	mut caught_29 := false
	if matched := caught(e_29, 'BaseException') {
		_ = matched
		caught_29 = true
	}
	// python: issubclass(TypeError, BaseException) == True
	assert caught_29 == true
	mut caught_30 := false
	if matched := caught(e_29, 'Exception') {
		_ = matched
		caught_30 = true
	}
	// python: issubclass(TypeError, Exception) == True
	assert caught_30 == true
	e_31 := raise('ValueError', 'x')
	mut caught_31 := false
	if matched := caught(e_31, 'BaseException') {
		_ = matched
		caught_31 = true
	}
	// python: issubclass(ValueError, BaseException) == True
	assert caught_31 == true
	mut caught_32 := false
	if matched := caught(e_31, 'Exception') {
		_ = matched
		caught_32 = true
	}
	// python: issubclass(ValueError, Exception) == True
	assert caught_32 == true
	e_33 := raise('AttributeError', 'x')
	mut caught_33 := false
	if matched := caught(e_33, 'BaseException') {
		_ = matched
		caught_33 = true
	}
	// python: issubclass(AttributeError, BaseException) == True
	assert caught_33 == true
	mut caught_34 := false
	if matched := caught(e_33, 'Exception') {
		_ = matched
		caught_34 = true
	}
	// python: issubclass(AttributeError, Exception) == True
	assert caught_34 == true
	e_35 := raise('RuntimeError', 'x')
	mut caught_35 := false
	if matched := caught(e_35, 'BaseException') {
		_ = matched
		caught_35 = true
	}
	// python: issubclass(RuntimeError, BaseException) == True
	assert caught_35 == true
	mut caught_36 := false
	if matched := caught(e_35, 'Exception') {
		_ = matched
		caught_36 = true
	}
	// python: issubclass(RuntimeError, Exception) == True
	assert caught_36 == true
	e_37 := raise('NotImplementedError', 'x')
	mut caught_37 := false
	if matched := caught(e_37, 'BaseException') {
		_ = matched
		caught_37 = true
	}
	// python: issubclass(NotImplementedError, BaseException) == True
	assert caught_37 == true
	mut caught_38 := false
	if matched := caught(e_37, 'Exception') {
		_ = matched
		caught_38 = true
	}
	// python: issubclass(NotImplementedError, Exception) == True
	assert caught_38 == true
	e_39 := raise('StopIteration', 'x')
	mut caught_39 := false
	if matched := caught(e_39, 'BaseException') {
		_ = matched
		caught_39 = true
	}
	// python: issubclass(StopIteration, BaseException) == True
	assert caught_39 == true
	mut caught_40 := false
	if matched := caught(e_39, 'Exception') {
		_ = matched
		caught_40 = true
	}
	// python: issubclass(StopIteration, Exception) == True
	assert caught_40 == true
	e_41 := raise('OSError', 'x')
	mut caught_41 := false
	if matched := caught(e_41, 'BaseException') {
		_ = matched
		caught_41 = true
	}
	// python: issubclass(OSError, BaseException) == True
	assert caught_41 == true
	mut caught_42 := false
	if matched := caught(e_41, 'Exception') {
		_ = matched
		caught_42 = true
	}
	// python: issubclass(OSError, Exception) == True
	assert caught_42 == true
	e_43 := raise('FileNotFoundError', 'x')
	mut caught_43 := false
	if matched := caught(e_43, 'BaseException') {
		_ = matched
		caught_43 = true
	}
	// python: issubclass(FileNotFoundError, BaseException) == True
	assert caught_43 == true
	mut caught_44 := false
	if matched := caught(e_43, 'Exception') {
		_ = matched
		caught_44 = true
	}
	// python: issubclass(FileNotFoundError, Exception) == True
	assert caught_44 == true
	e_45 := raise('PermissionError', 'x')
	mut caught_45 := false
	if matched := caught(e_45, 'BaseException') {
		_ = matched
		caught_45 = true
	}
	// python: issubclass(PermissionError, BaseException) == True
	assert caught_45 == true
	mut caught_46 := false
	if matched := caught(e_45, 'Exception') {
		_ = matched
		caught_46 = true
	}
	// python: issubclass(PermissionError, Exception) == True
	assert caught_46 == true
	e_47 := raise('FileExistsError', 'x')
	mut caught_47 := false
	if matched := caught(e_47, 'BaseException') {
		_ = matched
		caught_47 = true
	}
	// python: issubclass(FileExistsError, BaseException) == True
	assert caught_47 == true
	mut caught_48 := false
	if matched := caught(e_47, 'Exception') {
		_ = matched
		caught_48 = true
	}
	// python: issubclass(FileExistsError, Exception) == True
	assert caught_48 == true
	e_49 := raise('IsADirectoryError', 'x')
	mut caught_49 := false
	if matched := caught(e_49, 'BaseException') {
		_ = matched
		caught_49 = true
	}
	// python: issubclass(IsADirectoryError, BaseException) == True
	assert caught_49 == true
	mut caught_50 := false
	if matched := caught(e_49, 'Exception') {
		_ = matched
		caught_50 = true
	}
	// python: issubclass(IsADirectoryError, Exception) == True
	assert caught_50 == true
	e_51 := raise('NotADirectoryError', 'x')
	mut caught_51 := false
	if matched := caught(e_51, 'BaseException') {
		_ = matched
		caught_51 = true
	}
	// python: issubclass(NotADirectoryError, BaseException) == True
	assert caught_51 == true
	mut caught_52 := false
	if matched := caught(e_51, 'Exception') {
		_ = matched
		caught_52 = true
	}
	// python: issubclass(NotADirectoryError, Exception) == True
	assert caught_52 == true
	e_53 := raise('TimeoutError', 'x')
	mut caught_53 := false
	if matched := caught(e_53, 'BaseException') {
		_ = matched
		caught_53 = true
	}
	// python: issubclass(TimeoutError, BaseException) == True
	assert caught_53 == true
	mut caught_54 := false
	if matched := caught(e_53, 'Exception') {
		_ = matched
		caught_54 = true
	}
	// python: issubclass(TimeoutError, Exception) == True
	assert caught_54 == true
	e_55 := raise('UnicodeError', 'x')
	mut caught_55 := false
	if matched := caught(e_55, 'BaseException') {
		_ = matched
		caught_55 = true
	}
	// python: issubclass(UnicodeError, BaseException) == True
	assert caught_55 == true
	mut caught_56 := false
	if matched := caught(e_55, 'Exception') {
		_ = matched
		caught_56 = true
	}
	// python: issubclass(UnicodeError, Exception) == True
	assert caught_56 == true
	e_57 := raise('AssertionError', 'x')
	mut caught_57 := false
	if matched := caught(e_57, 'BaseException') {
		_ = matched
		caught_57 = true
	}
	// python: issubclass(AssertionError, BaseException) == True
	assert caught_57 == true
	mut caught_58 := false
	if matched := caught(e_57, 'Exception') {
		_ = matched
		caught_58 = true
	}
	// python: issubclass(AssertionError, Exception) == True
	assert caught_58 == true
	e_59 := raise('ImportError', 'x')
	mut caught_59 := false
	if matched := caught(e_59, 'BaseException') {
		_ = matched
		caught_59 = true
	}
	// python: issubclass(ImportError, BaseException) == True
	assert caught_59 == true
	mut caught_60 := false
	if matched := caught(e_59, 'Exception') {
		_ = matched
		caught_60 = true
	}
	// python: issubclass(ImportError, Exception) == True
	assert caught_60 == true
	e_61 := raise('KeyboardInterrupt', 'x')
	mut caught_61 := false
	if matched := caught(e_61, 'BaseException') {
		_ = matched
		caught_61 = true
	}
	// python: issubclass(KeyboardInterrupt, BaseException) == True
	assert caught_61 == true
	mut caught_62 := false
	if matched := caught(e_61, 'Exception') {
		_ = matched
		caught_62 = true
	}
	// python: issubclass(KeyboardInterrupt, Exception) == False
	assert caught_62 == false
	e_63 := raise('SystemExit', 'x')
	mut caught_63 := false
	if matched := caught(e_63, 'BaseException') {
		_ = matched
		caught_63 = true
	}
	// python: issubclass(SystemExit, BaseException) == True
	assert caught_63 == true
	mut caught_64 := false
	if matched := caught(e_63, 'Exception') {
		_ = matched
		caught_64 = true
	}
	// python: issubclass(SystemExit, Exception) == False
	assert caught_64 == false
	e_65 := raise('GeneratorExit', 'x')
	mut caught_65 := false
	if matched := caught(e_65, 'BaseException') {
		_ = matched
		caught_65 = true
	}
	// python: issubclass(GeneratorExit, BaseException) == True
	assert caught_65 == true
	mut caught_66 := false
	if matched := caught(e_65, 'Exception') {
		_ = matched
		caught_66 = true
	}
	// python: issubclass(GeneratorExit, Exception) == False
	assert caught_66 == false
	e_67 := raise('ExceptionGroup', 'x')
	mut caught_67 := false
	if matched := caught(e_67, 'BaseException') {
		_ = matched
		caught_67 = true
	}
	// python: issubclass(ExceptionGroup, BaseException) == True
	assert caught_67 == true
	mut caught_68 := false
	if matched := caught(e_67, 'Exception') {
		_ = matched
		caught_68 = true
	}
	// python: issubclass(ExceptionGroup, Exception) == True
	assert caught_68 == true
	e_69 := raise('BaseExceptionGroup', 'x')
	mut caught_69 := false
	if matched := caught(e_69, 'BaseException') {
		_ = matched
		caught_69 = true
	}
	// python: issubclass(BaseExceptionGroup, BaseException) == True
	assert caught_69 == true
	mut caught_70 := false
	if matched := caught(e_69, 'Exception') {
		_ = matched
		caught_70 = true
	}
	// python: issubclass(BaseExceptionGroup, Exception) == False
	assert caught_70 == false
	e_71 := raise('RecursionError', 'x')
	mut caught_71 := false
	if matched := caught(e_71, 'BaseException') {
		_ = matched
		caught_71 = true
	}
	// python: issubclass(RecursionError, BaseException) == True
	assert caught_71 == true
	mut caught_72 := false
	if matched := caught(e_71, 'Exception') {
		_ = matched
		caught_72 = true
	}
	// python: issubclass(RecursionError, Exception) == True
	assert caught_72 == true
	e_73 := raise('ModuleNotFoundError', 'x')
	mut caught_73 := false
	if matched := caught(e_73, 'BaseException') {
		_ = matched
		caught_73 = true
	}
	// python: issubclass(ModuleNotFoundError, BaseException) == True
	assert caught_73 == true
	mut caught_74 := false
	if matched := caught(e_73, 'Exception') {
		_ = matched
		caught_74 = true
	}
	// python: issubclass(ModuleNotFoundError, Exception) == True
	assert caught_74 == true
	e_75 := raise('BrokenPipeError', 'x')
	mut caught_75 := false
	if matched := caught(e_75, 'BaseException') {
		_ = matched
		caught_75 = true
	}
	// python: issubclass(BrokenPipeError, BaseException) == True
	assert caught_75 == true
	mut caught_76 := false
	if matched := caught(e_75, 'Exception') {
		_ = matched
		caught_76 = true
	}
	// python: issubclass(BrokenPipeError, Exception) == True
	assert caught_76 == true
	e_77 := raise('UnicodeDecodeError', 'x')
	mut caught_77 := false
	if matched := caught(e_77, 'BaseException') {
		_ = matched
		caught_77 = true
	}
	// python: issubclass(UnicodeDecodeError, BaseException) == True
	assert caught_77 == true
	mut caught_78 := false
	if matched := caught(e_77, 'Exception') {
		_ = matched
		caught_78 = true
	}
	// python: issubclass(UnicodeDecodeError, Exception) == True
	assert caught_78 == true
	e_79 := raise('Warning', 'x')
	mut caught_79 := false
	if matched := caught(e_79, 'BaseException') {
		_ = matched
		caught_79 = true
	}
	// python: issubclass(Warning, BaseException) == True
	assert caught_79 == true
	mut caught_80 := false
	if matched := caught(e_79, 'Exception') {
		_ = matched
		caught_80 = true
	}
	// python: issubclass(Warning, Exception) == True
	assert caught_80 == true
	e_81 := raise('DeprecationWarning', 'x')
	mut caught_81 := false
	if matched := caught(e_81, 'BaseException') {
		_ = matched
		caught_81 = true
	}
	// python: issubclass(DeprecationWarning, BaseException) == True
	assert caught_81 == true
	mut caught_82 := false
	if matched := caught(e_81, 'Exception') {
		_ = matched
		caught_82 = true
	}
	// python: issubclass(DeprecationWarning, Exception) == True
	assert caught_82 == true
	lookup := raise('KeyError', 'x')
	mut lookup_caught := false
	if matched := caught(lookup, 'TypeError', 'LookupError') {
		_ = matched
		lookup_caught = true
	}
	// python: issubclass(KeyError, (TypeError, LookupError))
	assert lookup_caught
	alias := raise('IOError', 'x')
	mut alias_caught := false
	if matched := caught(alias, 'EnvironmentError') {
		_ = matched
		alias_caught = true
	}
	// python: IOError is EnvironmentError
	assert alias_caught
}

fn test_exc_registration_chaining_and_host() {
	check_exc_registration_chaining_and_host() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_exc_registration_chaining_and_host() ! {
	register_exception('TestProjectError', ['Exception'])
	register_exception('TestMissing', ['TestProjectError', 'KeyError'])
	err := raise('TestMissing', 'lost')
	mut matched_root := false
	mut matched_lookup := false
	if e := caught(err, 'TestProjectError') {
		_ = e
		matched_root = true
	}
	if e := caught(err, 'LookupError') {
		_ = e
		matched_lookup = true
	}
	// python: exec_result("class TestProjectError(Exception): pass\nclass TestMissing(TestProjectError, KeyError): pass", "issubclass(TestMissing, TestProjectError)")
	assert matched_root
	// python: exec_result("class TestProjectError(Exception): pass\nclass TestMissing(TestProjectError, KeyError): pass", "issubclass(TestMissing, LookupError)")
	assert matched_lookup
	// python: exec_result("class TestProjectError(Exception): pass\nclass TestMissing(TestProjectError, KeyError): pass", "str(TestMissing('lost'))") == "'lost'" 
	assert err.msg() == '\'lost\''
	chained := raise_from('ValueError', 'outer', raise('TypeError', 'inner'))
	if e := caught(chained, 'ValueError') {
	// python: exec_result("cause=TypeError('inner')\ntry: raise ValueError('outer') from cause\nexcept ValueError as e: saved=e", "str(saved.__cause__)") == 'inner' 
	assert e.cause.msg() == 'inner'
	// python: exec_result("try: raise ValueError('outer') from None\nexcept ValueError as e: saved=e", "saved.__suppress_context__")
	assert e.suppress_context
	} else {
		// harness: the newly raised ValueError must be catchable.
		assert false, 'missing chained error'
	}
	host := IError(ExcTestHostError{})
	if e := caught(host, 'Exception') {
	// runtime: a plain V IError maps to Exception when explicitly broadly caught.
	assert e.class_name == 'Exception' && e.msg() == 'host failure'
	} else {
		// harness: broad host-error mapping is required.
		assert false, 'uncaught host error'
	}
	mut host_as_value_error := false
	if e := caught(host, 'ValueError') {
		_ = e
		host_as_value_error = true
	}
	// runtime: a host IError is not guessed to be a Python ValueError.
	assert !host_as_value_error
	if e := caught(host, 'BaseException') {
	// runtime: BaseException also catches a plain V error through the Exception adapter.
	assert e.class_name == 'Exception'
	} else {
		// harness: broad host-error mapping is required.
		assert false, 'uncaught host error'
	}
}

fn test_exc_completion_maybe_identity() {
	check_exc_completion_maybe_identity() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_exc_completion_maybe_identity() ! {
	mut completion := Completion{}
	// runtime: the protected-region carrier starts in normal completion with None.
	assert completion.flow == .normal && eq(completion.value, none_)
	completion.flow = .return_
	completion.value = Value(i64(7))
	// runtime: the lowering can carry a pending return through finally.
	assert completion.flow == .return_ && eq(completion.value, Value(i64(7)))
	present := some[int](7)
	absent := nothing[string]()
	// runtime: Maybe[int] carries an explicitly present value inside !Maybe[int].
	assert present.has && present.value == 7
	// runtime: Maybe[string] can represent absence without an unsupported !?string.
	assert !absent.has && absent.value == ''
	first := identity_token()
	second := identity_token()
	// runtime: identity allocation yields distinct nonzero tokens in serial execution.
	assert first != 0 && second != 0 && first != second
}

struct ExcTestHostError {
	Error
}

fn (e ExcTestHostError) msg() string {
	_ = e
	return 'host failure'
}

