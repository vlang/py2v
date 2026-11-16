module pyrt

fn test_format_strings_bytes_containers() {
	check_format_strings_bytes_containers() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_format_strings_bytes_containers() ! {
	got_1 := repr(Value(''))
	// python: (repr('')) == "''"
	assert got_1 == '\'\''
	got_2 := repr(Value('don\'t'))
	// python: (repr("don't")) == '"don\'t"'
	assert got_2 == '"don\'t"'
	got_3 := repr(Value('say "hi"'))
	// python: (repr('say "hi"')) == '\'say "hi"\''
	assert got_3 == '\'say "hi"\''
	got_4 := repr(Value('both \'"'))
	// python: (repr('both \'"')) == '\'both \\\'"\''
	assert got_4 == '\'both \\\'"\''
	got_5 := repr(Value('a\\b'))
	// python: (repr('a\\b')) == "'a\\\\b'"
	assert got_5 == '\'a\\\\b\''
	got_6 := repr(Value('\n\r\t'))
	// python: (repr('\n\r\t')) == "'\\n\\r\\t'"
	assert got_6 == '\'\\n\\r\\t\''
	got_7 := repr(Value('\x00\x07\x08\x0b\x0c\x1b\x7f'))
	// python: (repr('\x00\x07\x08\x0b\x0c\x1b\x7f')) == "'\\x00\\x07\\x08\\x0b\\x0c\\x1b\\x7f'"
	assert got_7 == '\'\\x00\\x07\\x08\\x0b\\x0c\\x1b\\x7f\''
	got_8 := repr(Value(' '))
	// python: (repr('\x85\xa0')) == "'\\x85\\xa0'"
	assert got_8 == '\'\\x85\\xa0\''
	got_9 := repr(Value('é中🙂'))
	// python: (repr('é中🙂')) == "'é中🙂'"
	assert got_9 == '\'é中🙂\''
	got_10 := repr(Value('á'))
	// python: (repr('á')) == "'á'"
	assert got_10 == '\'á\''
	got_11 := repr(Value('​ 　'))
	// python: (repr('\u200b\u2028\u3000')) == "'\\u200b\\u2028\\u3000'"
	assert got_11 == '\'\\u200b\\u2028\\u3000\''
	got_12 := repr(Value('􏿿'))
	// python: (repr('\U0010ffff')) == "'\\U0010ffff'"
	assert got_12 == '\'\\U0010ffff\''
	got_13 := repr(Value([]u8{}))
	// python: (repr(b'')) == "b''"
	assert got_13 == 'b\'\''
	got_14 := repr(Value([u8(100), u8(111), u8(110), u8(39), u8(116)]))
	// python: (repr(b"don't")) == 'b"don\'t"'
	assert got_14 == 'b"don\'t"'
	got_15 := repr(Value([u8(115), u8(97), u8(121), u8(32), u8(34), u8(104), u8(105), u8(34)]))
	// python: (repr(b'say "hi"')) == 'b\'say "hi"\''
	assert got_15 == 'b\'say "hi"\''
	got_16 := repr(Value([u8(39), u8(34), u8(92), u8(10), u8(13), u8(9), u8(0), u8(255)]))
	// python: (repr(b'\'"\\\n\r\t\x00\xff')) == 'b\'\\\'"\\\\\\n\\r\\t\\x00\\xff\''
	assert got_16 == 'b\'\\\'"\\\\\\n\\r\\t\\x00\\xff\''
	got_17 := repr(Value([u8(32), u8(33), u8(34), u8(35), u8(36), u8(37), u8(38), u8(39), u8(40), u8(41), u8(42), u8(43), u8(44), u8(45), u8(46), u8(47), u8(48), u8(49), u8(50), u8(51), u8(52), u8(53), u8(54), u8(55), u8(56), u8(57), u8(58), u8(59), u8(60), u8(61), u8(62), u8(63), u8(64), u8(65), u8(66), u8(67), u8(68), u8(69), u8(70), u8(71), u8(72), u8(73), u8(74), u8(75), u8(76), u8(77), u8(78), u8(79), u8(80), u8(81), u8(82), u8(83), u8(84), u8(85), u8(86), u8(87), u8(88), u8(89), u8(90), u8(91), u8(92), u8(93), u8(94), u8(95), u8(96), u8(97), u8(98), u8(99), u8(100), u8(101), u8(102), u8(103), u8(104), u8(105), u8(106), u8(107), u8(108), u8(109), u8(110), u8(111), u8(112), u8(113), u8(114), u8(115), u8(116), u8(117), u8(118), u8(119), u8(120), u8(121), u8(122), u8(123), u8(124), u8(125), u8(126)]))
	// python: (repr(b' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~')) == 'b\' !"#$%&\\\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\''
	assert got_17 == 'b\' !"#\$%&\\\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\''
	got_18 := repr(none_)
	// python: (repr(None)) == 'None'
	assert got_18 == 'None'
	got_19 := repr(Value(true))
	// python: (repr(True)) == 'True'
	assert got_19 == 'True'
	got_20 := repr(Value(false))
	// python: (repr(False)) == 'False'
	assert got_20 == 'False'
	got_21 := repr(Value(i64(1)))
	// python: (repr(1)) == '1'
	assert got_21 == '1'
	got_22 := repr(Value(i64(-1)))
	// python: (repr(-1)) == '-1'
	assert got_22 == '-1'
	got_23 := repr(Value(new_list([]Value{})))
	// python: (repr([])) == '[]'
	assert got_23 == '[]'
	got_24 := repr(Value(new_list([Value(i64(1)), Value(true), none_, Value('é')])))
	// python: (repr([1, True, None, 'é'])) == "[1, True, None, 'é']"
	assert got_24 == '[1, True, None, \'é\']'
	got_25 := repr(Value(new_tuple([]Value{})))
	// python: (repr(())) == '()'
	assert got_25 == '()'
	got_26 := repr(Value(new_tuple([Value(i64(1))])))
	// python: (repr((1,))) == '(1,)'
	assert got_26 == '(1,)'
	got_27 := repr(Value(new_tuple([Value('x'), Value(i64(1))])))
	// python: (repr(('x', 1))) == "('x', 1)"
	assert got_27 == '(\'x\', 1)'
	got_28 := repr(format_test_dict([]Value{}, []Value{})!)
	// python: (repr({})) == '{}'
	assert got_28 == '{}'
	got_29 := repr(format_test_dict([Value('a'), Value('b')], [Value(new_list([Value(i64(1)), none_])), Value(new_tuple([Value(i64(2))]))])!)
	// python: (repr({'a': [1, None], 'b': (2,)})) == "{'a': [1, None], 'b': (2,)}"
	assert got_29 == '{\'a\': [1, None], \'b\': (2,)}'
	got_30 := repr(Value(new_set([]Value{})!))
	// python: (repr(set())) == 'set()'
	assert got_30 == 'set()'
	got_31 := repr(Value(new_set([Value(i64(1))])!))
	// python: (repr({1})) == '{1}'
	assert got_31 == '{1}'
	got_32 := str(Value('plain'))
	// python: (str('plain')) == 'plain'
	assert got_32 == 'plain'
	got_33 := str(Value(true))
	// python: (str(True)) == 'True'
	assert got_33 == 'True'
	got_34 := str(none_)
	// python: (str(None)) == 'None'
	assert got_34 == 'None'
}

fn test_format_float_boundaries() {
	check_format_float_boundaries() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_format_float_boundaries() ! {
	got_35 := repr(Value(0.0))
	// python: (repr(0.0)) == '0.0'
	assert got_35 == '0.0'
	got_36 := repr(Value(-0.0))
	// python: (repr(-0.0)) == '-0.0'
	assert got_36 == '-0.0'
	got_37 := repr(Value(format_test_binary(i64(4503599627370496), -52)))
	// python: (repr(math.ldexp(4503599627370496, -52))) == '1.0'
	assert got_37 == '1.0'
	got_38 := repr(Value(format_test_binary(i64(-4503599627370496), -52)))
	// python: (repr(math.ldexp(-4503599627370496, -52))) == '-1.0'
	assert got_38 == '-1.0'
	got_39 := repr(Value(format_test_binary(i64(7205759403792794), -56)))
	// python: (repr(math.ldexp(7205759403792794, -56))) == '0.1'
	assert got_39 == '0.1'
	got_40 := repr(Value(format_test_binary(i64(5404319552844595), -54)))
	// python: (repr(math.ldexp(5404319552844595, -54))) == '0.3'
	assert got_40 == '0.3'
	got_41 := repr(Value(format_test_binary(i64(5902958103587057), -69)))
	// python: (repr(math.ldexp(5902958103587057, -69))) == '1e-05'
	assert got_41 == '1e-05'
	got_42 := repr(Value(format_test_binary(i64(7378697629483821), -66)))
	// python: (repr(math.ldexp(7378697629483821, -66))) == '0.0001'
	assert got_42 == '0.0001'
	got_43 := repr(Value(format_test_binary(i64(8000000000000000), -3)))
	// python: (repr(math.ldexp(8000000000000000, -3))) == '1000000000000000.0'
	assert got_43 == '1000000000000000.0'
	got_44 := repr(Value(format_test_binary(i64(5000000000000000), 1)))
	// python: (repr(math.ldexp(5000000000000000, 1))) == '1e+16'
	assert got_44 == '1e+16'
	got_45 := repr(Value(format_test_binary(i64(6103515625000000), 14)))
	// python: (repr(math.ldexp(6103515625000000, 14))) == '1e+20'
	assert got_45 == '1e+20'
	got_46 := repr(Value(format_test_binary(i64(7629394531250000), 17)))
	// python: (repr(math.ldexp(7629394531250000, 17))) == '1e+21'
	assert got_46 == '1e+21'
	got_47 := repr(Value(format_test_binary(i64(5559999489923579), -52)))
	// python: (repr(math.ldexp(5559999489923579, -52))) == '1.2345678901234567'
	assert got_47 == '1.2345678901234567'
	got_48 := repr(Value(format_test_binary(i64(4503599627370496), -1074)))
	// python: (repr(math.ldexp(4503599627370496, -1074))) == '2.2250738585072014e-308'
	assert got_48 == '2.2250738585072014e-308'
	got_49 := repr(Value(format_test_binary(i64(9007199254740990), -1075)))
	// python: (repr(math.ldexp(9007199254740990, -1075))) == '2.225073858507201e-308'
	assert got_49 == '2.225073858507201e-308'
	got_50 := repr(Value(format_test_binary(i64(4503599627370496), -1126)))
	// python: (repr(math.ldexp(4503599627370496, -1126))) == '5e-324'
	assert got_50 == '5e-324'
	got_51 := repr(Value(format_test_binary(i64(4503599627370496), -1125)))
	// python: (repr(math.ldexp(4503599627370496, -1125))) == '1e-323'
	assert got_51 == '1e-323'
	got_52 := repr(Value(format_test_binary(i64(9007199254740991), 971)))
	// python: (repr(math.ldexp(9007199254740991, 971))) == '1.7976931348623157e+308'
	assert got_52 == '1.7976931348623157e+308'
	got_53 := repr(Value(format_test_binary(i64(9007199254740990), -1075)))
	// python: (repr(math.ldexp(9007199254740990, -1075))) == '2.225073858507201e-308'
	assert got_53 == '2.225073858507201e-308'
	got_54 := repr(Value(format_test_binary(i64(4503599627370496), -1074)))
	// python: (repr(math.ldexp(4503599627370496, -1074))) == '2.2250738585072014e-308'
	assert got_54 == '2.2250738585072014e-308'
	got_55 := repr(Value(format_test_binary(i64(4503599627370497), -1074)))
	// python: (repr(math.ldexp(4503599627370497, -1074))) == '2.225073858507202e-308'
	assert got_55 == '2.225073858507202e-308'
	got_56 := repr(Value(format_test_binary(i64(9007199254740991), -1074)))
	// python: (repr(math.ldexp(9007199254740991, -1074))) == '4.4501477170144023e-308'
	assert got_56 == '4.4501477170144023e-308'
	got_57 := repr(Value(format_test_binary(i64(4503599627370496), -1073)))
	// python: (repr(math.ldexp(4503599627370496, -1073))) == '4.450147717014403e-308'
	assert got_57 == '4.450147717014403e-308'
	got_58 := repr(Value(format_test_binary(i64(4503599627370497), -1073)))
	// python: (repr(math.ldexp(4503599627370497, -1073))) == '4.450147717014404e-308'
	assert got_58 == '4.450147717014404e-308'
	got_59 := repr(Value(format_test_binary(i64(9007199254740991), -106)))
	// python: (repr(math.ldexp(9007199254740991, -106))) == '1.1102230246251564e-16'
	assert got_59 == '1.1102230246251564e-16'
	got_60 := repr(Value(format_test_binary(i64(4503599627370496), -105)))
	// python: (repr(math.ldexp(4503599627370496, -105))) == '1.1102230246251565e-16'
	assert got_60 == '1.1102230246251565e-16'
	got_61 := repr(Value(format_test_binary(i64(4503599627370497), -105)))
	// python: (repr(math.ldexp(4503599627370497, -105))) == '1.1102230246251568e-16'
	assert got_61 == '1.1102230246251568e-16'
	got_62 := repr(Value(format_test_binary(i64(9007199254740991), -105)))
	// python: (repr(math.ldexp(9007199254740991, -105))) == '2.2204460492503128e-16'
	assert got_62 == '2.2204460492503128e-16'
	got_63 := repr(Value(format_test_binary(i64(4503599627370496), -104)))
	// python: (repr(math.ldexp(4503599627370496, -104))) == '2.220446049250313e-16'
	assert got_63 == '2.220446049250313e-16'
	got_64 := repr(Value(format_test_binary(i64(4503599627370497), -104)))
	// python: (repr(math.ldexp(4503599627370497, -104))) == '2.2204460492503136e-16'
	assert got_64 == '2.2204460492503136e-16'
	got_65 := repr(Value(format_test_binary(i64(9007199254740991), -54)))
	// python: (repr(math.ldexp(9007199254740991, -54))) == '0.49999999999999994'
	assert got_65 == '0.49999999999999994'
	got_66 := repr(Value(format_test_binary(i64(4503599627370496), -53)))
	// python: (repr(math.ldexp(4503599627370496, -53))) == '0.5'
	assert got_66 == '0.5'
	got_67 := repr(Value(format_test_binary(i64(4503599627370497), -53)))
	// python: (repr(math.ldexp(4503599627370497, -53))) == '0.5000000000000001'
	assert got_67 == '0.5000000000000001'
	got_68 := repr(Value(format_test_binary(i64(9007199254740991), -53)))
	// python: (repr(math.ldexp(9007199254740991, -53))) == '0.9999999999999999'
	assert got_68 == '0.9999999999999999'
	got_69 := repr(Value(format_test_binary(i64(4503599627370496), -52)))
	// python: (repr(math.ldexp(4503599627370496, -52))) == '1.0'
	assert got_69 == '1.0'
	got_70 := repr(Value(format_test_binary(i64(4503599627370497), -52)))
	// python: (repr(math.ldexp(4503599627370497, -52))) == '1.0000000000000002'
	assert got_70 == '1.0000000000000002'
	got_71 := repr(Value(format_test_binary(i64(9007199254740991), -52)))
	// python: (repr(math.ldexp(9007199254740991, -52))) == '1.9999999999999998'
	assert got_71 == '1.9999999999999998'
	got_72 := repr(Value(format_test_binary(i64(4503599627370496), -51)))
	// python: (repr(math.ldexp(4503599627370496, -51))) == '2.0'
	assert got_72 == '2.0'
	got_73 := repr(Value(format_test_binary(i64(4503599627370497), -51)))
	// python: (repr(math.ldexp(4503599627370497, -51))) == '2.0000000000000004'
	assert got_73 == '2.0000000000000004'
	got_74 := repr(Value(format_test_binary(i64(9007199254740991), -1)))
	// python: (repr(math.ldexp(9007199254740991, -1))) == '4503599627370495.5'
	assert got_74 == '4503599627370495.5'
	got_75 := repr(Value(format_test_binary(i64(4503599627370496), 0)))
	// python: (repr(math.ldexp(4503599627370496, 0))) == '4503599627370496.0'
	assert got_75 == '4503599627370496.0'
	got_76 := repr(Value(format_test_binary(i64(4503599627370497), 0)))
	// python: (repr(math.ldexp(4503599627370497, 0))) == '4503599627370497.0'
	assert got_76 == '4503599627370497.0'
	got_77 := repr(Value(format_test_binary(i64(9007199254740991), 0)))
	// python: (repr(math.ldexp(9007199254740991, 0))) == '9007199254740991.0'
	assert got_77 == '9007199254740991.0'
	got_78 := repr(Value(format_test_binary(i64(4503599627370496), 1)))
	// python: (repr(math.ldexp(4503599627370496, 1))) == '9007199254740992.0'
	assert got_78 == '9007199254740992.0'
	got_79 := repr(Value(format_test_binary(i64(4503599627370497), 1)))
	// python: (repr(math.ldexp(4503599627370497, 1))) == '9007199254740994.0'
	assert got_79 == '9007199254740994.0'
	got_80 := repr(Value(format_test_binary(i64(9007199254740991), 10)))
	// python: (repr(math.ldexp(9007199254740991, 10))) == '9.223372036854775e+18'
	assert got_80 == '9.223372036854775e+18'
	got_81 := repr(Value(format_test_binary(i64(4503599627370496), 11)))
	// python: (repr(math.ldexp(4503599627370496, 11))) == '9.223372036854776e+18'
	assert got_81 == '9.223372036854776e+18'
	got_82 := repr(Value(format_test_binary(i64(4503599627370497), 11)))
	// python: (repr(math.ldexp(4503599627370497, 11))) == '9.223372036854778e+18'
	assert got_82 == '9.223372036854778e+18'
	got_83 := repr(Value(format_test_binary(i64(9007199254740991), 47)))
	// python: (repr(math.ldexp(9007199254740991, 47))) == '1.2676506002282293e+30'
	assert got_83 == '1.2676506002282293e+30'
	got_84 := repr(Value(format_test_binary(i64(4503599627370496), 48)))
	// python: (repr(math.ldexp(4503599627370496, 48))) == '1.2676506002282294e+30'
	assert got_84 == '1.2676506002282294e+30'
	got_85 := repr(Value(format_test_binary(i64(4503599627370497), 48)))
	// python: (repr(math.ldexp(4503599627370497, 48))) == '1.2676506002282297e+30'
	assert got_85 == '1.2676506002282297e+30'
	got_86 := repr(Value(format_test_binary(i64(9007199254740991), 970)))
	// python: (repr(math.ldexp(9007199254740991, 970))) == '8.988465674311579e+307'
	assert got_86 == '8.988465674311579e+307'
	got_87 := repr(Value(format_test_binary(i64(4503599627370496), 971)))
	// python: (repr(math.ldexp(4503599627370496, 971))) == '8.98846567431158e+307'
	assert got_87 == '8.98846567431158e+307'
	got_88 := repr(Value(format_test_binary(i64(4503599627370497), 971)))
	// python: (repr(math.ldexp(4503599627370497, 971))) == '8.988465674311582e+307'
	assert got_88 == '8.988465674311582e+307'
	got_89 := repr(Value(format_test_binary(i64(-8241885462204399), -863)))
	// python: (repr(math.ldexp(-8241885462204399, -863))) == '-1.3401095953596167e-244'
	assert got_89 == '-1.3401095953596167e-244'
	got_90 := repr(Value(format_test_binary(i64(-6998286062979730), 773)))
	// python: (repr(math.ldexp(-6998286062979730, 773))) == '-3.4767890329190174e+248'
	assert got_90 == '-3.4767890329190174e+248'
	got_91 := repr(Value(format_test_binary(i64(-5756969967326381), 44)))
	// python: (repr(math.ldexp(-5756969967326381, 44))) == '-1.012776867173212e+29'
	assert got_91 == '-1.012776867173212e+29'
	got_92 := repr(Value(format_test_binary(i64(-7118723495953426), 667)))
	// python: (repr(math.ldexp(-7118723495953426, 667))) == '-4.359224465938816e+216'
	assert got_92 == '-4.359224465938816e+216'
	got_93 := repr(Value(format_test_binary(i64(-6393958227223673), -126)))
	// python: (repr(math.ldexp(-6393958227223673, -126))) == '-7.516061775495116e-23'
	assert got_93 == '-7.516061775495116e-23'
	got_94 := repr(Value(format_test_binary(i64(-6572940157143519), 614)))
	// python: (repr(math.ldexp(-6572940157143519, 614))) == '-4.468656949721516e+200'
	assert got_94 == '-4.468656949721516e+200'
	got_95 := repr(Value(format_test_binary(i64(-6298919273598501), 928)))
	// python: (repr(math.ldexp(-6298919273598501, 928))) == '-1.4292296546901803e+295'
	assert got_95 == '-1.4292296546901803e+295'
	got_96 := repr(Value(format_test_binary(i64(-5232662466985878), -1001)))
	// python: (repr(math.ldexp(-5232662466985878, -1001))) == '-2.4417267541726103e-286'
	assert got_96 == '-2.4417267541726103e-286'
	got_97 := repr(Value(format_test_binary(i64(6496784554439312), -449)))
	// python: (repr(math.ldexp(6496784554439312, -449))) == '4.469206398390144e-120'
	assert got_97 == '4.469206398390144e-120'
	got_98 := repr(Value(format_test_binary(i64(-6178451615950760), 827)))
	// python: (repr(math.ldexp(-6178451615950760, 827))) == '-5.5295025685675055e+264'
	assert got_98 == '-5.5295025685675055e+264'
	got_99 := repr(Value(format_test_binary(i64(8087041929774577), 47)))
	// python: (repr(math.ldexp(8087041929774577, 47))) == '1.1381499694206988e+30'
	assert got_99 == '1.1381499694206988e+30'
	got_100 := repr(Value(format_test_binary(i64(-8467085408594050), 285)))
	// python: (repr(math.ldexp(-8467085408594050, 285))) == '-5.263597897950092e+101'
	assert got_100 == '-5.263597897950092e+101'
	got_101 := repr(Value(format_test_binary(i64(-5727088951082448), 803)))
	// python: (repr(math.ldexp(-5727088951082448, 803))) == '-3.0550649427363607e+257'
	assert got_101 == '-3.0550649427363607e+257'
	got_102 := repr(Value(format_test_binary(i64(-7610002955879641), -594)))
	// python: (repr(math.ldexp(-7610002955879641, -594))) == '-1.1737278269994249e-163'
	assert got_102 == '-1.1737278269994249e-163'
	got_103 := repr(Value(format_test_binary(i64(5439063191005759), -589)))
	// python: (repr(math.ldexp(5439063191005759, -589))) == '2.6844582771823946e-162'
	assert got_103 == '2.6844582771823946e-162'
	got_104 := repr(Value(format_test_binary(i64(-8953921742678149), -1066)))
	// python: (repr(math.ldexp(-8953921742678149, -1066))) == '-1.1324992329237144e-305'
	assert got_104 == '-1.1324992329237144e-305'
	got_105 := repr(Value(format_test_binary(i64(5440690706113890), 384)))
	// python: (repr(math.ldexp(5440690706113890, 384))) == '2.1437412891496535e+131'
	assert got_105 == '2.1437412891496535e+131'
	got_106 := repr(Value(format_test_binary(i64(4674083047585821), 583)))
	// python: (repr(math.ldexp(4674083047585821, 583))) == '1.4797348309478823e+191'
	assert got_106 == '1.4797348309478823e+191'
	got_107 := repr(Value(format_test_binary(i64(-6829063053064664), -261)))
	// python: (repr(math.ldexp(-6829063053064664, -261))) == '-1.8430293624885724e-63'
	assert got_107 == '-1.8430293624885724e-63'
	got_108 := repr(Value(format_test_binary(i64(-5003645005514298), 117)))
	// python: (repr(math.ldexp(-5003645005514298, 117))) == '-8.313731277873718e+50'
	assert got_108 == '-8.313731277873718e+50'
	got_109 := repr(Value(format_test_binary(i64(-6345659966251491), -810)))
	// python: (repr(math.ldexp(-6345659966251491, -810))) == '-9.293521517043377e-229'
	assert got_109 == '-9.293521517043377e-229'
	got_110 := repr(Value(format_test_binary(i64(-8053434353431158), -252)))
	// python: (repr(math.ldexp(-8053434353431158, -252))) == '-1.1128130643779124e-60'
	assert got_110 == '-1.1128130643779124e-60'
	got_111 := repr(Value(format_test_binary(i64(-6399126978307683), 571)))
	// python: (repr(math.ldexp(-6399126978307683, 571))) == '-4.945933264444417e+187'
	assert got_111 == '-4.945933264444417e+187'
	got_112 := repr(Value(format_test_binary(i64(8949661770682146), -933)))
	// python: (repr(math.ldexp(8949661770682146, -933))) == '1.2325957560980135e-265'
	assert got_112 == '1.2325957560980135e-265'
	got_113 := repr(Value(format_test_binary(i64(-8508852693374507), -772)))
	// python: (repr(math.ldexp(-8508852693374507, -772))) == '-3.4254241285382787e-217'
	assert got_113 == '-3.4254241285382787e-217'
	got_114 := repr(Value(format_test_binary(i64(8304148096060932), 384)))
	// python: (repr(math.ldexp(8304148096060932, 384))) == '3.2720009473677026e+131'
	assert got_114 == '3.2720009473677026e+131'
	got_115 := repr(Value(format_test_binary(i64(5790194507671148), -194)))
	// python: (repr(math.ldexp(5790194507671148, -194))) == '2.3060780085136144e-43'
	assert got_115 == '2.3060780085136144e-43'
	got_116 := repr(Value(format_test_binary(i64(7118158477385482), -510)))
	// python: (repr(math.ldexp(7118158477385482, -510))) == '2.1235860521208874e-138'
	assert got_116 == '2.1235860521208874e-138'
	got_117 := repr(Value(format_test_binary(i64(5940160031172276), -340)))
	// python: (repr(math.ldexp(5940160031172276, -340))) == '2.6521593819643894e-87'
	assert got_117 == '2.6521593819643894e-87'
	got_118 := repr(Value(format_test_binary(i64(-5130687868398926), 828)))
	// python: (repr(math.ldexp(-5130687868398926, 828))) == '-9.183579806172622e+264'
	assert got_118 == '-9.183579806172622e+264'
	got_119 := repr(Value(format_test_binary(i64(5328436692134509), 441)))
	// python: (repr(math.ldexp(5328436692134509, 441))) == '3.025714162344492e+148'
	assert got_119 == '3.025714162344492e+148'
	got_120 := repr(Value(format_test_binary(i64(7361130901402953), -976)))
	// python: (repr(math.ldexp(7361130901402953, -976))) == '1.1525738786309475e-278'
	assert got_120 == '1.1525738786309475e-278'
	got_121 := repr(Value(format_test_binary(i64(-8552183661306785), 633)))
	// python: (repr(math.ldexp(-8552183661306785, 633))) == '-3.04834610200867e+206'
	assert got_121 == '-3.04834610200867e+206'
	got_122 := repr(Value(format_test_binary(i64(-7449082177039978), 665)))
	// python: (repr(math.ldexp(-7449082177039978, 665))) == '-1.1403807611505066e+216'
	assert got_122 == '-1.1403807611505066e+216'
	got_123 := repr(Value(format_test_binary(i64(-5309426972262786), -948)))
	// python: (repr(math.ldexp(-5309426972262786, -948))) == '-2.231576412309383e-270'
	assert got_123 == '-2.231576412309383e-270'
	got_124 := repr(Value(format_test_binary(i64(6861213158448841), -821)))
	// python: (repr(math.ldexp(6861213158448841, -821))) == '4.9065301481173066e-232'
	assert got_124 == '4.9065301481173066e-232'
	got_125 := repr(Value(format_test_binary(i64(-5951614361573464), -296)))
	// python: (repr(math.ldexp(-5951614361573464, -296))) == '-4.674724987259583e-74'
	assert got_125 == '-4.674724987259583e-74'
	got_126 := repr(Value(format_test_binary(i64(-7769293847344186), -735)))
	// python: (repr(math.ldexp(-7769293847344186, -735))) == '-4.2986762154774353e-206'
	assert got_126 == '-4.2986762154774353e-206'
	got_127 := repr(Value(format_test_binary(i64(6168091840621637), -603)))
	// python: (repr(math.ldexp(6168091840621637, -603))) == '1.858075882061637e-166'
	assert got_127 == '1.858075882061637e-166'
	got_128 := repr(Value(format_test_binary(i64(-5167447613224162), 434)))
	// python: (repr(math.ldexp(-5167447613224162, 434))) == '-2.2924200629029715e+146'
	assert got_128 == '-2.2924200629029715e+146'
	got_129 := repr(Value(format_test_binary(i64(-4726591363096658), -22)))
	// python: (repr(math.ldexp(-4726591363096658, -22))) == '-1126907196.7832227'
	assert got_129 == '-1126907196.7832227'
	got_130 := repr(Value(format_test_binary(i64(7424751402217782), 737)))
	// python: (repr(math.ldexp(7424751402217782, 737))) == '5.3677060095491654e+237'
	assert got_130 == '5.3677060095491654e+237'
	got_131 := repr(Value(format_test_binary(i64(5874152769283449), -371)))
	// python: (repr(math.ldexp(5874152769283449, -371))) == '1.2212845012539839e-96'
	assert got_131 == '1.2212845012539839e-96'
	got_132 := repr(Value(format_test_binary(i64(-6594296921723142), -866)))
	// python: (repr(math.ldexp(-6594296921723142, -866))) == '-1.3402698660362076e-245'
	assert got_132 == '-1.3402698660362076e-245'
	got_133 := repr(Value(format_test_binary(i64(6028079126735202), -802)))
	// python: (repr(math.ldexp(6028079126735202, -802))) == '2.260072765068885e-226'
	assert got_133 == '2.260072765068885e-226'
	got_134 := repr(Value(format_test_binary(i64(5849926841033728), 181)))
	// python: (repr(math.ldexp(5849926841033728, 181))) == '1.7929973596551727e+70'
	assert got_134 == '1.7929973596551727e+70'
	got_135 := repr(Value(format_test_binary(i64(-4555833212491497), -115)))
	// python: (repr(math.ldexp(-4555833212491497, -115))) == '-1.0967769506964089e-19'
	assert got_135 == '-1.0967769506964089e-19'
	got_136 := repr(Value(format_test_binary(i64(-5081872232673158), 862)))
	// python: (repr(math.ldexp(-5081872232673158, 862))) == '-1.5627158040014458e+275'
	assert got_136 == '-1.5627158040014458e+275'
	got_137 := repr(Value(format_test_binary(i64(7327837587655246), 99)))
	// python: (repr(math.ldexp(7327837587655246, 99))) == '4.6445688581830766e+45'
	assert got_137 == '4.6445688581830766e+45'
	got_138 := repr(Value(format_test_binary(i64(5970736937381160), -791)))
	// python: (repr(math.ldexp(5970736937381160, -791))) == '4.584599122738935e-223'
	assert got_138 == '4.584599122738935e-223'
	got_139 := repr(Value(format_test_binary(i64(4682580124329110), 605)))
	// python: (repr(math.ldexp(4682580124329110, 605))) == '6.217740521099628e+197'
	assert got_139 == '6.217740521099628e+197'
	got_140 := repr(Value(format_test_binary(i64(-8796012529690200), -979)))
	// python: (repr(math.ldexp(-8796012529690200, -979))) == '-1.7215517584226156e-279'
	assert got_140 == '-1.7215517584226156e-279'
	got_141 := repr(Value(format_test_binary(i64(-8815262660151145), 613)))
	// python: (repr(math.ldexp(-8815262660151145, 613))) == '-2.9965573858977754e+200'
	assert got_141 == '-2.9965573858977754e+200'
	got_142 := repr(Value(format_test_binary(i64(-5459142456201308), 691)))
	// python: (repr(math.ldexp(-5459142456201308, 691))) == '-5.608560786236615e+223'
	assert got_142 == '-5.608560786236615e+223'
	got_143 := repr(Value(format_test_binary(i64(4966947975312446), 900)))
	// python: (repr(math.ldexp(4966947975312446, 900))) == '4.198418322868689e+286'
	assert got_143 == '4.198418322868689e+286'
	got_144 := repr(Value(format_test_binary(i64(-5219984074802817), 202)))
	// python: (repr(math.ldexp(-5219984074802817, 202))) == '-3.3552764000906854e+76'
	assert got_144 == '-3.3552764000906854e+76'
	got_145 := repr(Value(format_test_binary(i64(4710851322969871), -533)))
	// python: (repr(math.ldexp(4710851322969871, -533))) == '1.6753737593047413e-145'
	assert got_145 == '1.6753737593047413e-145'
	got_146 := repr(Value(format_test_binary(i64(6088588021370044), -890)))
	// python: (repr(math.ldexp(6088588021370044, -890))) == '7.375992186215084e-253'
	assert got_146 == '7.375992186215084e-253'
	got_147 := repr(Value(format_test_binary(i64(-8167902796399518), 361)))
	// python: (repr(math.ldexp(-8167902796399518, 361))) == '-3.836533505860348e+124'
	assert got_147 == '-3.836533505860348e+124'
	got_148 := repr(Value(format_test_binary(i64(6787009569126755), -900)))
	// python: (repr(math.ldexp(6787009569126755, -900))) == '8.029386508290227e-256'
	assert got_148 == '8.029386508290227e-256'
	got_149 := repr(Value(infinity()))
	// python: (repr(float('inf'))) == 'inf'
	assert got_149 == 'inf'
	got_150 := repr(Value(-infinity()))
	// python: (repr(float('-inf'))) == '-inf'
	assert got_150 == '-inf'
	got_151 := repr(Value(infinity() - infinity()))
	// python: (repr(float('nan'))) == 'nan'
	assert got_151 == 'nan'
}

fn test_format_recursive_repr() {
	check_format_recursive_repr() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_format_recursive_repr() ! {
	mut a := new_list([]Value{})
	a.items << Value(a)
	// python: exec_result("a=[]; a.append(a)", "repr(a)") == '[[...]]' 
	assert repr(Value(a)) == '[[...]]'
	d := Value(new_dict())
	setitem(d, Value('self'), d)!
	// python: exec_result("d={}; d['self']=d", "repr(d)") == "{'self': {...}}" 
	assert repr(d) == '{\'self\': {...}}'
	mut b := new_list([]Value{})
	tu := Value(new_tuple([Value(b)]))
	b.items << tu
	// python: exec_result("b=[]; t=(b,); b.append(t)", "repr(t)") == '([(...)],)' 
	assert repr(tu) == '([(...)],)'
	child := Value(new_list([Value(i64(1))]))
	shared := Value(new_list([child, child]))
	// python: exec_result("a=[1]; b=[a,a]", "repr(b)") == '[[1], [1]]' 
	assert repr(shared) == '[[1], [1]]'
}

fn format_test_binary(significand i64, exponent int) f64 {
	mut out := f64(significand)
	mut power := exponent
	for power > 0 { out = out * 2.0
		 power = power - 1 }
	for power < 0 { out = out * 0.5
		 power = power + 1 }
	return out
}

fn format_test_dict(keys []Value, values []Value) !Value {
	d := Value(new_dict())
	for i, key in keys { setitem(d, key, values[i])! }
	return d
}
