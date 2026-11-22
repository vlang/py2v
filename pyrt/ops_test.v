module pyrt

fn test_ops_add() {
	check_ops_add() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_add() ! {
	got_1 := add(Value(i64(1)), Value(i64(2)))!
	// python: repr((1 + 2)) == '3'
	assert repr(got_1) == '3'
	got_2 := add(Value(true), Value(true))!
	// python: repr((True + True)) == '2'
	assert repr(got_2) == '2'
	got_3 := add(Value(false), Value(i64(2)))!
	// python: repr((False + 2)) == '2'
	assert repr(got_3) == '2'
	got_4 := add(Value(i64(2)), Value(1.5))!
	// python: repr((2 + 1.5)) == '3.5'
	assert repr(got_4) == '3.5'
	got_5 := add(Value(1.5), Value(i64(2)))!
	// python: repr((1.5 + 2)) == '3.5'
	assert repr(got_5) == '3.5'
	got_6 := add(Value(1.5), Value(2.5))!
	// python: repr((1.5 + 2.5)) == '4.0'
	assert repr(got_6) == '4.0'
	got_7 := add(Value('a'), Value('b'))!
	// python: repr(('a' + 'b')) == "'ab'"
	assert repr(got_7) == '\'ab\''
	got_8 := add(Value(new_list([Value(i64(1))])), Value(new_list([Value(i64(2))])))!
	// python: repr(([1] + [2])) == '[1, 2]'
	assert repr(got_8) == '[1, 2]'
	got_9 := add(Value(new_tuple([Value(i64(1))])), Value(new_tuple([Value(i64(2))])))!
	// python: repr(((1,) + (2,))) == '(1, 2)'
	assert repr(got_9) == '(1, 2)'
	got_10 := add(Value([u8(97)]), Value([u8(255)]))!
	// python: repr((b'a' + b'\xff')) == "b'a\\xff'"
	assert repr(got_10) == 'b\'a\\xff\''
}

fn test_ops_subtract() {
	check_ops_subtract() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_subtract() ! {
	got_11 := sub(Value(i64(7)), Value(i64(2)))!
	// python: repr((7 - 2)) == '5'
	assert repr(got_11) == '5'
	got_12 := sub(Value(true), Value(false))!
	// python: repr((True - False)) == '1'
	assert repr(got_12) == '1'
	got_13 := sub(Value(i64(-7)), Value(i64(2)))!
	// python: repr((-7 - 2)) == '-9'
	assert repr(got_13) == '-9'
	got_14 := sub(Value(i64(7)), Value(2.5))!
	// python: repr((7 - 2.5)) == '4.5'
	assert repr(got_14) == '4.5'
	got_15 := sub(Value(2.5), Value(i64(7)))!
	// python: repr((2.5 - 7)) == '-4.5'
	assert repr(got_15) == '-4.5'
	got_16 := sub(Value(-2.5), Value(i64(-7)))!
	// python: repr((-2.5 - -7)) == '4.5'
	assert repr(got_16) == '4.5'
	got_17 := sub(Value(new_set([Value(i64(1)), Value(i64(2))])!), Value(new_set([Value(i64(2))])!))!
	// python: repr(({1, 2} - {2})) == '{1}'
	assert repr(got_17) == '{1}'
}

fn test_ops_multiply() {
	check_ops_multiply() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_multiply() ! {
	got_18 := mul(Value(i64(7)), Value(i64(-2)))!
	// python: repr((7 * -2)) == '-14'
	assert repr(got_18) == '-14'
	got_19 := mul(Value(true), Value(i64(4)))!
	// python: repr((True * 4)) == '4'
	assert repr(got_19) == '4'
	got_20 := mul(Value(false), Value(i64(4)))!
	// python: repr((False * 4)) == '0'
	assert repr(got_20) == '0'
	got_21 := mul(Value(1.5), Value(i64(2)))!
	// python: repr((1.5 * 2)) == '3.0'
	assert repr(got_21) == '3.0'
	got_22 := mul(Value('ab'), Value(i64(3)))!
	// python: repr(('ab' * 3)) == "'ababab'"
	assert repr(got_22) == '\'ababab\''
	got_23 := mul(Value(i64(3)), Value('ab'))!
	// python: repr((3 * 'ab')) == "'ababab'"
	assert repr(got_23) == '\'ababab\''
	got_24 := mul(Value('a'), Value(i64(0)))!
	// python: repr(('a' * 0)) == "''"
	assert repr(got_24) == '\'\''
	got_25 := mul(Value('a'), Value(i64(-2)))!
	// python: repr(('a' * -2)) == "''"
	assert repr(got_25) == '\'\''
	got_26 := mul(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(i64(2)))!
	// python: repr(([1, 2] * 2)) == '[1, 2, 1, 2]'
	assert repr(got_26) == '[1, 2, 1, 2]'
	got_27 := mul(Value(new_tuple([Value(i64(1))])), Value(i64(3)))!
	// python: repr(((1,) * 3)) == '(1, 1, 1)'
	assert repr(got_27) == '(1, 1, 1)'
	got_28 := mul(Value([u8(120), u8(121)]), Value(i64(2)))!
	// python: repr((b'xy' * 2)) == "b'xyxy'"
	assert repr(got_28) == 'b\'xyxy\''
}

fn test_ops_division() {
	check_ops_division() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_division() ! {
	got_29 := truediv(Value(i64(7)), Value(i64(2)))!
	// python: repr((7 / 2)) == '3.5'
	assert repr(got_29) == '3.5'
	got_30 := truediv(Value(i64(-7)), Value(i64(2)))!
	// python: repr((-7 / 2)) == '-3.5'
	assert repr(got_30) == '-3.5'
	got_31 := truediv(Value(i64(7)), Value(i64(-2)))!
	// python: repr((7 / -2)) == '-3.5'
	assert repr(got_31) == '-3.5'
	got_32 := truediv(Value(i64(-7)), Value(i64(-2)))!
	// python: repr((-7 / -2)) == '3.5'
	assert repr(got_32) == '3.5'
	got_33 := truediv(Value(true), Value(i64(2)))!
	// python: repr((True / 2)) == '0.5'
	assert repr(got_33) == '0.5'
	got_34 := truediv(Value(i64(0)), Value(i64(-2)))!
	// python: repr((0 / -2)) == '-0.0'
	assert repr(got_34) == '-0.0'
	got_35 := truediv(Value(i64(7)), Value(2.0))!
	// python: repr((7 / 2.0)) == '3.5'
	assert repr(got_35) == '3.5'
	got_36 := truediv(Value(7.0), Value(i64(2)))!
	// python: repr((7.0 / 2)) == '3.5'
	assert repr(got_36) == '3.5'
	got_37 := truediv(Value(i64(9223372036854775807)), Value(i64(9007199254740993)))!
	// python: repr((9223372036854775807 / 9007199254740993)) == '1023.9999999999999'
	assert repr(got_37) == '1023.9999999999999'
	got_38 := truediv(Value(i64(9223372036854775807)), Value(i64(3)))!
	// python: repr((9223372036854775807 / 3)) == '3.0744573456182584e+18'
	assert repr(got_38) == '3.0744573456182584e+18'
	got_39 := truediv(Value(int_min), Value(i64(9223372036854775807)))!
	// python: repr((-9223372036854775808 / 9223372036854775807)) == '-1.0'
	assert repr(got_39) == '-1.0'
}

fn test_ops_floor() {
	check_ops_floor() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_floor() ! {
	got_40 := floordiv(Value(i64(7)), Value(i64(2)))!
	// python: repr((7 // 2)) == '3'
	assert repr(got_40) == '3'
	got_41 := floordiv(Value(i64(-7)), Value(i64(2)))!
	// python: repr((-7 // 2)) == '-4'
	assert repr(got_41) == '-4'
	got_42 := floordiv(Value(i64(7)), Value(i64(-2)))!
	// python: repr((7 // -2)) == '-4'
	assert repr(got_42) == '-4'
	got_43 := floordiv(Value(i64(-7)), Value(i64(-2)))!
	// python: repr((-7 // -2)) == '3'
	assert repr(got_43) == '3'
	got_44 := floordiv(Value(i64(-1)), Value(i64(2)))!
	// python: repr((-1 // 2)) == '-1'
	assert repr(got_44) == '-1'
	got_45 := floordiv(Value(i64(1)), Value(i64(-2)))!
	// python: repr((1 // -2)) == '-1'
	assert repr(got_45) == '-1'
	got_46 := floordiv(Value(true), Value(i64(2)))!
	// python: repr((True // 2)) == '0'
	assert repr(got_46) == '0'
	got_47 := floordiv(Value(int_min), Value(i64(1)))!
	// python: repr((-9223372036854775808 // 1)) == '-9223372036854775808'
	assert repr(got_47) == '-9223372036854775808'
	got_48 := floordiv(Value(7.0), Value(2.0))!
	// python: repr((7.0 // 2.0)) == '3.0'
	assert repr(got_48) == '3.0'
	got_49 := floordiv(Value(-7.0), Value(2.0))!
	// python: repr((-7.0 // 2.0)) == '-4.0'
	assert repr(got_49) == '-4.0'
	got_50 := floordiv(Value(7.0), Value(-2.0))!
	// python: repr((7.0 // -2.0)) == '-4.0'
	assert repr(got_50) == '-4.0'
	got_51 := floordiv(Value(-7.0), Value(-2.0))!
	// python: repr((-7.0 // -2.0)) == '3.0'
	assert repr(got_51) == '3.0'
	got_52 := floordiv(Value(1.0), Value(0.1))!
	// python: repr((1.0 // 0.1)) == '9.0'
	assert repr(got_52) == '9.0'
	got_53 := floordiv(Value(-0.0), Value(2.0))!
	// python: repr((-0.0 // 2.0)) == '-0.0'
	assert repr(got_53) == '-0.0'
	got_54 := floordiv(Value(0.0), Value(-2.0))!
	// python: repr((0.0 // -2.0)) == '-0.0'
	assert repr(got_54) == '-0.0'
	got_55 := floordiv(Value(1.0), Value(infinity()))!
	// python: repr((1.0 // float('inf'))) == '0.0'
	assert repr(got_55) == '0.0'
	got_56 := floordiv(Value(-1.0), Value(infinity()))!
	// python: repr((-1.0 // float('inf'))) == '-1.0'
	assert repr(got_56) == '-1.0'
	got_57 := floordiv(Value(1.0), Value(-infinity()))!
	// python: repr((1.0 // float('-inf'))) == '-1.0'
	assert repr(got_57) == '-1.0'
}

fn test_ops_modulo() {
	check_ops_modulo() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_modulo() ! {
	got_58 := mod(Value(i64(7)), Value(i64(2)))!
	// python: repr((7 % 2)) == '1'
	assert repr(got_58) == '1'
	got_59 := mod(Value(i64(-7)), Value(i64(2)))!
	// python: repr((-7 % 2)) == '1'
	assert repr(got_59) == '1'
	got_60 := mod(Value(i64(7)), Value(i64(-2)))!
	// python: repr((7 % -2)) == '-1'
	assert repr(got_60) == '-1'
	got_61 := mod(Value(i64(-7)), Value(i64(-2)))!
	// python: repr((-7 % -2)) == '-1'
	assert repr(got_61) == '-1'
	got_62 := mod(Value(true), Value(i64(2)))!
	// python: repr((True % 2)) == '1'
	assert repr(got_62) == '1'
	got_63 := mod(Value(int_min), Value(i64(-1)))!
	// python: repr((-9223372036854775808 % -1)) == '0'
	assert repr(got_63) == '0'
	got_64 := mod(Value(7.0), Value(2.0))!
	// python: repr((7.0 % 2.0)) == '1.0'
	assert repr(got_64) == '1.0'
	got_65 := mod(Value(-7.0), Value(2.0))!
	// python: repr((-7.0 % 2.0)) == '1.0'
	assert repr(got_65) == '1.0'
	got_66 := mod(Value(7.0), Value(-2.0))!
	// python: repr((7.0 % -2.0)) == '-1.0'
	assert repr(got_66) == '-1.0'
	got_67 := mod(Value(-7.0), Value(-2.0))!
	// python: repr((-7.0 % -2.0)) == '-1.0'
	assert repr(got_67) == '-1.0'
	got_68 := mod(Value(1.0), Value(0.1))!
	// python: repr((1.0 % 0.1)) == '0.09999999999999995'
	assert repr(got_68) == '0.09999999999999995'
	got_69 := mod(Value(-0.0), Value(2.0))!
	// python: repr((-0.0 % 2.0)) == '0.0'
	assert repr(got_69) == '0.0'
	got_70 := mod(Value(0.0), Value(-2.0))!
	// python: repr((0.0 % -2.0)) == '-0.0'
	assert repr(got_70) == '-0.0'
	got_71 := mod(Value(1.0), Value(infinity()))!
	// python: repr((1.0 % float('inf'))) == '1.0'
	assert repr(got_71) == '1.0'
	got_72 := mod(Value(-1.0), Value(infinity()))!
	// python: repr((-1.0 % float('inf'))) == 'inf'
	assert repr(got_72) == 'inf'
	got_73 := mod(Value(1.0), Value(-infinity()))!
	// python: repr((1.0 % float('-inf'))) == '-inf'
	assert repr(got_73) == '-inf'
}

fn test_ops_power() {
	check_ops_power() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_power() ! {
	got_74 := pow(Value(i64(2)), Value(i64(10)))!
	// python: repr((2 ** 10)) == '1024'
	assert repr(got_74) == '1024'
	got_75 := pow(Value(i64(2)), Value(i64(0)))!
	// python: repr((2 ** 0)) == '1'
	assert repr(got_75) == '1'
	got_76 := pow(Value(i64(0)), Value(i64(0)))!
	// python: repr((0 ** 0)) == '1'
	assert repr(got_76) == '1'
	got_77 := pow(Value(i64(-2)), Value(i64(5)))!
	// python: repr((-2 ** 5)) == '-32'
	assert repr(got_77) == '-32'
	got_78 := pow(Value(true), Value(i64(3)))!
	// python: repr((True ** 3)) == '1'
	assert repr(got_78) == '1'
	got_79 := pow(Value(i64(2)), Value(i64(-3)))!
	// python: repr((2 ** -3)) == '0.125'
	assert repr(got_79) == '0.125'
	got_80 := pow(Value(i64(-2)), Value(i64(-3)))!
	// python: repr((-2 ** -3)) == '-0.125'
	assert repr(got_80) == '-0.125'
	got_81 := pow(Value(2.0), Value(i64(10)))!
	// python: repr((2.0 ** 10)) == '1024.0'
	assert repr(got_81) == '1024.0'
	got_82 := pow(Value(4.0), Value(i64(-1)))!
	// python: repr((4.0 ** -1)) == '0.25'
	assert repr(got_82) == '0.25'
	got_83 := pow(Value(i64(2)), Value(3.0))!
	// python: repr((2 ** 3.0)) == '8.0'
	assert repr(got_83) == '8.0'
	got_84 := pow(Value(-0.0), Value(i64(3)))!
	// python: repr(((-0.0) ** 3)) == '-0.0'
	assert repr(got_84) == '-0.0'
	got_85 := pow(Value(-0.0), Value(i64(2)))!
	// python: repr(((-0.0) ** 2)) == '0.0'
	assert repr(got_85) == '0.0'
}

fn test_ops_negation() {
	check_ops_negation() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_negation() ! {
	got_86 := neg(Value(true))!
	// python: repr(-(True)) == '-1'
	assert repr(got_86) == '-1'
	got_87 := neg(Value(false))!
	// python: repr(-(False)) == '0'
	assert repr(got_87) == '0'
	got_88 := neg(Value(i64(0)))!
	// python: repr(-(0)) == '0'
	assert repr(got_88) == '0'
	got_89 := neg(Value(i64(1)))!
	// python: repr(-(1)) == '-1'
	assert repr(got_89) == '-1'
	got_90 := neg(Value(i64(-2)))!
	// python: repr(-(-2)) == '2'
	assert repr(got_90) == '2'
	got_91 := neg(Value(1.5))!
	// python: repr(-(1.5)) == '-1.5'
	assert repr(got_91) == '-1.5'
	got_92 := neg(Value(-0.0))!
	// python: repr(-(-0.0)) == '0.0'
	assert repr(got_92) == '0.0'
}

fn test_ops_comparisons() {
	check_ops_comparisons() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_comparisons() ! {
	got_93 := eq(Value(i64(1)), Value(true))
	// python: (1 == True) == True
	assert got_93 == true
	got_94 := lt(Value(i64(1)), Value(true))!
	// python: (1 < True) == False
	assert got_94 == false
	got_95 := le(Value(i64(1)), Value(true))!
	// python: (1 <= True) == True
	assert got_95 == true
	got_96 := gt(Value(i64(1)), Value(true))!
	// python: (1 > True) == False
	assert got_96 == false
	got_97 := ge(Value(i64(1)), Value(true))!
	// python: (1 >= True) == True
	assert got_97 == true
	got_98 := eq(Value(i64(1)), Value(1.0))
	// python: (1 == 1.0) == True
	assert got_98 == true
	got_99 := lt(Value(i64(1)), Value(1.0))!
	// python: (1 < 1.0) == False
	assert got_99 == false
	got_100 := le(Value(i64(1)), Value(1.0))!
	// python: (1 <= 1.0) == True
	assert got_100 == true
	got_101 := gt(Value(i64(1)), Value(1.0))!
	// python: (1 > 1.0) == False
	assert got_101 == false
	got_102 := ge(Value(i64(1)), Value(1.0))!
	// python: (1 >= 1.0) == True
	assert got_102 == true
	got_103 := eq(Value(i64(9007199254740993)), Value(9007199254740992.0))
	// python: (9007199254740993 == 9007199254740992.0) == False
	assert got_103 == false
	got_104 := lt(Value(i64(9007199254740993)), Value(9007199254740992.0))!
	// python: (9007199254740993 < 9007199254740992.0) == False
	assert got_104 == false
	got_105 := le(Value(i64(9007199254740993)), Value(9007199254740992.0))!
	// python: (9007199254740993 <= 9007199254740992.0) == False
	assert got_105 == false
	got_106 := gt(Value(i64(9007199254740993)), Value(9007199254740992.0))!
	// python: (9007199254740993 > 9007199254740992.0) == True
	assert got_106 == true
	got_107 := ge(Value(i64(9007199254740993)), Value(9007199254740992.0))!
	// python: (9007199254740993 >= 9007199254740992.0) == True
	assert got_107 == true
	got_108 := eq(Value(i64(9223372036854775807)), Value(9.223372036854776e+18))
	// python: (9223372036854775807 == 9.223372036854776e+18) == False
	assert got_108 == false
	got_109 := lt(Value(i64(9223372036854775807)), Value(9.223372036854776e+18))!
	// python: (9223372036854775807 < 9.223372036854776e+18) == True
	assert got_109 == true
	got_110 := le(Value(i64(9223372036854775807)), Value(9.223372036854776e+18))!
	// python: (9223372036854775807 <= 9.223372036854776e+18) == True
	assert got_110 == true
	got_111 := gt(Value(i64(9223372036854775807)), Value(9.223372036854776e+18))!
	// python: (9223372036854775807 > 9.223372036854776e+18) == False
	assert got_111 == false
	got_112 := ge(Value(i64(9223372036854775807)), Value(9.223372036854776e+18))!
	// python: (9223372036854775807 >= 9.223372036854776e+18) == False
	assert got_112 == false
	got_113 := eq(Value(int_min), Value(-9.223372036854776e+18))
	// python: (-9223372036854775808 == -9.223372036854776e+18) == True
	assert got_113 == true
	got_114 := lt(Value(int_min), Value(-9.223372036854776e+18))!
	// python: (-9223372036854775808 < -9.223372036854776e+18) == False
	assert got_114 == false
	got_115 := le(Value(int_min), Value(-9.223372036854776e+18))!
	// python: (-9223372036854775808 <= -9.223372036854776e+18) == True
	assert got_115 == true
	got_116 := gt(Value(int_min), Value(-9.223372036854776e+18))!
	// python: (-9223372036854775808 > -9.223372036854776e+18) == False
	assert got_116 == false
	got_117 := ge(Value(int_min), Value(-9.223372036854776e+18))!
	// python: (-9223372036854775808 >= -9.223372036854776e+18) == True
	assert got_117 == true
	got_118 := eq(Value(i64(1)), Value(1.5))
	// python: (1 == 1.5) == False
	assert got_118 == false
	got_119 := lt(Value(i64(1)), Value(1.5))!
	// python: (1 < 1.5) == True
	assert got_119 == true
	got_120 := le(Value(i64(1)), Value(1.5))!
	// python: (1 <= 1.5) == True
	assert got_120 == true
	got_121 := gt(Value(i64(1)), Value(1.5))!
	// python: (1 > 1.5) == False
	assert got_121 == false
	got_122 := ge(Value(i64(1)), Value(1.5))!
	// python: (1 >= 1.5) == False
	assert got_122 == false
	got_123 := eq(Value(i64(1)), Value(-1.5))
	// python: (1 == -1.5) == False
	assert got_123 == false
	got_124 := lt(Value(i64(1)), Value(-1.5))!
	// python: (1 < -1.5) == False
	assert got_124 == false
	got_125 := le(Value(i64(1)), Value(-1.5))!
	// python: (1 <= -1.5) == False
	assert got_125 == false
	got_126 := gt(Value(i64(1)), Value(-1.5))!
	// python: (1 > -1.5) == True
	assert got_126 == true
	got_127 := ge(Value(i64(1)), Value(-1.5))!
	// python: (1 >= -1.5) == True
	assert got_127 == true
	got_128 := eq(Value('é'), Value('中'))
	// python: ('é' == '中') == False
	assert got_128 == false
	got_129 := lt(Value('é'), Value('中'))!
	// python: ('é' < '中') == True
	assert got_129 == true
	got_130 := le(Value('é'), Value('中'))!
	// python: ('é' <= '中') == True
	assert got_130 == true
	got_131 := gt(Value('é'), Value('中'))!
	// python: ('é' > '中') == False
	assert got_131 == false
	got_132 := ge(Value('é'), Value('中'))!
	// python: ('é' >= '中') == False
	assert got_132 == false
	got_133 := eq(Value([u8(97)]), Value([u8(98)]))
	// python: (b'a' == b'b') == False
	assert got_133 == false
	got_134 := lt(Value([u8(97)]), Value([u8(98)]))!
	// python: (b'a' < b'b') == True
	assert got_134 == true
	got_135 := le(Value([u8(97)]), Value([u8(98)]))!
	// python: (b'a' <= b'b') == True
	assert got_135 == true
	got_136 := gt(Value([u8(97)]), Value([u8(98)]))!
	// python: (b'a' > b'b') == False
	assert got_136 == false
	got_137 := ge(Value([u8(97)]), Value([u8(98)]))!
	// python: (b'a' >= b'b') == False
	assert got_137 == false
	got_138 := eq(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(new_list([Value(i64(1)), Value(i64(3))])))
	// python: ([1, 2] == [1, 3]) == False
	assert got_138 == false
	got_139 := lt(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(new_list([Value(i64(1)), Value(i64(3))])))!
	// python: ([1, 2] < [1, 3]) == True
	assert got_139 == true
	got_140 := le(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(new_list([Value(i64(1)), Value(i64(3))])))!
	// python: ([1, 2] <= [1, 3]) == True
	assert got_140 == true
	got_141 := gt(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(new_list([Value(i64(1)), Value(i64(3))])))!
	// python: ([1, 2] > [1, 3]) == False
	assert got_141 == false
	got_142 := ge(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(new_list([Value(i64(1)), Value(i64(3))])))!
	// python: ([1, 2] >= [1, 3]) == False
	assert got_142 == false
	got_143 := eq(Value(new_list([Value(i64(1))])), Value(new_list([Value(i64(1)), Value(i64(0))])))
	// python: ([1] == [1, 0]) == False
	assert got_143 == false
	got_144 := lt(Value(new_list([Value(i64(1))])), Value(new_list([Value(i64(1)), Value(i64(0))])))!
	// python: ([1] < [1, 0]) == True
	assert got_144 == true
	got_145 := le(Value(new_list([Value(i64(1))])), Value(new_list([Value(i64(1)), Value(i64(0))])))!
	// python: ([1] <= [1, 0]) == True
	assert got_145 == true
	got_146 := gt(Value(new_list([Value(i64(1))])), Value(new_list([Value(i64(1)), Value(i64(0))])))!
	// python: ([1] > [1, 0]) == False
	assert got_146 == false
	got_147 := ge(Value(new_list([Value(i64(1))])), Value(new_list([Value(i64(1)), Value(i64(0))])))!
	// python: ([1] >= [1, 0]) == False
	assert got_147 == false
	got_148 := eq(Value(new_tuple([Value(i64(1)), Value(i64(2))])), Value(new_tuple([Value(i64(1)), Value(i64(2))])))
	// python: ((1, 2) == (1, 2)) == True
	assert got_148 == true
	got_149 := lt(Value(new_tuple([Value(i64(1)), Value(i64(2))])), Value(new_tuple([Value(i64(1)), Value(i64(2))])))!
	// python: ((1, 2) < (1, 2)) == False
	assert got_149 == false
	got_150 := le(Value(new_tuple([Value(i64(1)), Value(i64(2))])), Value(new_tuple([Value(i64(1)), Value(i64(2))])))!
	// python: ((1, 2) <= (1, 2)) == True
	assert got_150 == true
	got_151 := gt(Value(new_tuple([Value(i64(1)), Value(i64(2))])), Value(new_tuple([Value(i64(1)), Value(i64(2))])))!
	// python: ((1, 2) > (1, 2)) == False
	assert got_151 == false
	got_152 := ge(Value(new_tuple([Value(i64(1)), Value(i64(2))])), Value(new_tuple([Value(i64(1)), Value(i64(2))])))!
	// python: ((1, 2) >= (1, 2)) == True
	assert got_152 == true
	got_153 := eq(Value(new_set([Value(i64(1))])!), Value(new_set([Value(i64(1)), Value(i64(2))])!))
	// python: ({1} == {1, 2}) == False
	assert got_153 == false
	got_154 := lt(Value(new_set([Value(i64(1))])!), Value(new_set([Value(i64(1)), Value(i64(2))])!))!
	// python: ({1} < {1, 2}) == True
	assert got_154 == true
	got_155 := le(Value(new_set([Value(i64(1))])!), Value(new_set([Value(i64(1)), Value(i64(2))])!))!
	// python: ({1} <= {1, 2}) == True
	assert got_155 == true
	got_156 := gt(Value(new_set([Value(i64(1))])!), Value(new_set([Value(i64(1)), Value(i64(2))])!))!
	// python: ({1} > {1, 2}) == False
	assert got_156 == false
	got_157 := ge(Value(new_set([Value(i64(1))])!), Value(new_set([Value(i64(1)), Value(i64(2))])!))!
	// python: ({1} >= {1, 2}) == False
	assert got_157 == false
	got_158 := eq(none_, none_)
	// python: (None == None) == True
	assert got_158 == true
	got_159 := eq(none_, Value(i64(0)))
	// python: (None == 0) == False
	assert got_159 == false
	got_160 := eq(Value(new_list([]Value{})), Value(new_tuple([]Value{})))
	// python: ([] == ()) == False
	assert got_160 == false
	got_161 := eq(ops_test_dict([Value('a')], [Value(i64(1))])!, ops_test_dict([Value('a')], [Value(i64(1))])!)
	// python: ({'a': 1} == {'a': 1}) == True
	assert got_161 == true
	got_162 := eq(ops_test_dict([Value('a')], [Value(i64(1))])!, ops_test_dict([Value('a')], [Value(i64(2))])!)
	// python: ({'a': 1} == {'a': 2}) == False
	assert got_162 == false
	got_163 := eq(Value(new_set([Value(i64(1)), Value(i64(2))])!), Value(new_set([Value(i64(1)), Value(i64(2))])!))
	// python: ({1, 2} == {1, 2}) == True
	assert got_163 == true
	got_164 := eq(Value(infinity() - infinity()), Value(i64(1)))
	// python: (float('nan') == 1) == False
	assert got_164 == false
	got_165 := lt(Value(infinity() - infinity()), Value(i64(1)))!
	// python: (float('nan') < 1) == False
	assert got_165 == false
	got_166 := le(Value(infinity() - infinity()), Value(i64(1)))!
	// python: (float('nan') <= 1) == False
	assert got_166 == false
	got_167 := gt(Value(infinity() - infinity()), Value(i64(1)))!
	// python: (float('nan') > 1) == False
	assert got_167 == false
	got_168 := ge(Value(infinity() - infinity()), Value(i64(1)))!
	// python: (float('nan') >= 1) == False
	assert got_168 == false
}

fn test_ops_keys_and_mapping() {
	check_ops_keys_and_mapping() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_keys_and_mapping() ! {
	d := Value(new_dict())
	setitem(d, Value(i64(1)), Value('int'))!
	setitem(d, Value(1.0), Value('float'))!
	setitem(d, Value(true), Value('bool'))!
	// python: repr({1: 'int', 1.0: 'float', True: 'bool'}) == "{1: 'bool'}"
	assert repr(d) == '{1: \'bool\'}'
	got_170 := len_(d)!
	// python: (len({1:"int", 1.0:"float", True:"bool"})) == 1
	assert got_170 == 1
	setitem(d, Value('second'), Value(i64(2)))!
	delitem(d, Value(1.0))!
	setitem(d, Value(true), Value('again'))!
	// python: exec_result("d={1:'bool','second':2}; del d[1.0]; d[True]='again'", "repr(d)") == "{'second': 2, True: 'again'}"
	assert repr(d) == '{\'second\': 2, True: \'again\'}'
	got_172 := hash_key(Value(i64(1)))! == hash_key(Value(true))!
	// python: (hash(1) == hash(True)) == True
	assert got_172 == true
	got_173 := hash_key(Value(i64(1)))! == hash_key(Value(1.0))!
	// python: (hash(1) == hash(1.0)) == True
	assert got_173 == true
	got_174 := hash_key(Value(i64(0)))! == hash_key(Value(-0.0))!
	// python: (hash(0) == hash(-0.0)) == True
	assert got_174 == true
	got_175 := hash_key(Value(int_min))! == hash_key(Value(-9223372036854775808.0))!
	// python: (hash(-(2**63)) == hash(float(-(2**63)))) == True
	assert got_175 == true
	tuple_key := Value(new_tuple([Value(i64(1)), Value('x'), none_]))
	setitem(d, tuple_key, Value('tuple value'))!
	got_176 := getitem(d, Value(new_tuple([Value(true), Value('x'), none_])))!
	// python: repr({(1, 'x', None): 'tuple value'}[(True, 'x', None)]) == "'tuple value'"
	assert repr(got_176) == '\'tuple value\''
	got_177 := hash_key(Value('1'))! != hash_key(Value(i64(1)))!
	// python: ('1' != 1) == True
	assert got_177 == true
	setitem(d, none_, Value('none value'))!
	got_178 := getitem(d, none_)!
	// python: repr({None:'none value'}[None]) == "'none value'"
	assert repr(got_178) == '\'none value\''
	got_179 := getitem(ops_test_dict([Value([u8(120)])], [Value(i64(1))])!, Value([u8(120)]))!
	// python: repr({b'x':1}[b'x']) == '1'
	assert repr(got_179) == '1'
}

fn test_ops_indexing_slicing_membership() {
	check_ops_indexing_slicing_membership() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_indexing_slicing_membership() ! {
	got_180 := getitem(Value(new_list([Value(i64(1)), Value(i64(2)), Value(i64(3))])), Value(i64(-1)))!
	// python: repr([1, 2, 3][-1]) == '3'
	assert repr(got_180) == '3'
	got_181 := getitem(Value(new_list([Value(i64(1)), Value(i64(2)), Value(i64(3))])), Value(true))!
	// python: repr([1, 2, 3][True]) == '2'
	assert repr(got_181) == '2'
	got_182 := getitem(Value(new_tuple([Value(i64(1)), Value(i64(2))])), Value(i64(-2)))!
	// python: repr((1, 2)[-2]) == '1'
	assert repr(got_182) == '1'
	got_183 := getitem(Value('Aé🙂'), Value(i64(-1)))!
	// python: repr('Aé🙂'[-1]) == "'🙂'"
	assert repr(got_183) == '\'🙂\''
	got_184 := getitem(Value('Aé🙂'), Value(i64(1)))!
	// python: repr('Aé🙂'[1]) == "'é'"
	assert repr(got_184) == '\'é\''
	got_185 := getitem(Value([u8(0), u8(255)]), Value(i64(-1)))!
	// python: repr(b'\x00\xff'[-1]) == '255'
	assert repr(got_185) == '255'
	got_186 := getitem(ops_test_dict([Value('x')], [none_])!, Value('x'))!
	// python: repr({'x': None}['x']) == 'None'
	assert repr(got_186) == 'None'
	got_187 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2)), Value(i64(3)), Value(i64(4))])), none, none, -1)!
	// python: repr([0, 1, 2, 3, 4][slice(None, None, -1)]) == '[4, 3, 2, 1, 0]'
	assert repr(got_187) == '[4, 3, 2, 1, 0]'
	got_188 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2)), Value(i64(3)), Value(i64(4))])), 1, 4, 2)!
	// python: repr([0, 1, 2, 3, 4][slice(1, 4, 2)]) == '[1, 3]'
	assert repr(got_188) == '[1, 3]'
	got_189 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2)), Value(i64(3)), Value(i64(4))])), none, -1, -1)!
	// python: repr([0, 1, 2, 3, 4][slice(None, -1, -1)]) == '[]'
	assert repr(got_189) == '[]'
	got_190 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2))])), -999, 999, none)!
	// python: repr([0, 1, 2][slice(-999, 999, None)]) == '[0, 1, 2]'
	assert repr(got_190) == '[0, 1, 2]'
	got_191 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2))])), 999, -999, -1)!
	// python: repr([0, 1, 2][slice(999, -999, -1)]) == '[2, 1, 0]'
	assert repr(got_191) == '[2, 1, 0]'
	got_192 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2))])), none, none, 9223372036854775807)!
	// python: repr([0, 1, 2][slice(None, None, 9223372036854775807)]) == '[0]'
	assert repr(got_192) == '[0]'
	got_193 := getslice(Value(new_list([Value(i64(0)), Value(i64(1)), Value(i64(2))])), none, none, int(int_min))!
	// python: repr([0, 1, 2][slice(None, None, -9223372036854775808)]) == '[2]'
	assert repr(got_193) == '[2]'
	got_194 := getslice(Value(new_tuple([Value(i64(0)), Value(i64(1)), Value(i64(2)), Value(i64(3))])), none, none, -2)!
	// python: repr((0, 1, 2, 3)[slice(None, None, -2)]) == '(3, 1)'
	assert repr(got_194) == '(3, 1)'
	got_195 := getslice(Value('Aé🙂'), none, none, -1)!
	// python: repr('Aé🙂'[slice(None, None, -1)]) == "'🙂éA'"
	assert repr(got_195) == '\'🙂éA\''
	got_196 := getslice(Value([u8(97), u8(98), u8(99), u8(100)]), 1, 4, 2)!
	// python: repr(b'abcd'[slice(1, 4, 2)]) == "b'bd'"
	assert repr(got_196) == 'b\'bd\''
	got_197 := getslice(Value(new_list([]Value{})), none, none, -1)!
	// python: repr([][slice(None, None, -1)]) == '[]'
	assert repr(got_197) == '[]'
	got_198 := contains(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(true))!
	// python: (True in [1, 2]) == True
	assert got_198 == true
	got_199 := contains(Value(new_list([Value(i64(1)), Value(i64(2))])), Value(i64(3)))!
	// python: (3 in [1, 2]) == False
	assert got_199 == false
	got_200 := contains(Value(new_tuple([none_])), none_)!
	// python: (None in (None,)) == True
	assert got_200 == true
	got_201 := contains(Value('Aé🙂'), Value('é'))!
	// python: ('é' in 'Aé🙂') == True
	assert got_201 == true
	got_202 := contains(Value('abc'), Value(''))!
	// python: ('' in 'abc') == True
	assert got_202 == true
	got_203 := contains(Value([u8(97), u8(98)]), Value(i64(97)))!
	// python: (97 in b'ab') == True
	assert got_203 == true
	got_204 := contains(Value([u8(97), u8(98)]), Value([u8(97), u8(98)]))!
	// python: (b'ab' in b'ab') == True
	assert got_204 == true
	got_205 := contains(Value([u8(97), u8(98)]), Value([]u8{}))!
	// python: (b'' in b'ab') == True
	assert got_205 == true
	got_206 := contains(ops_test_dict([Value(i64(1))], [Value('x')])!, Value(true))!
	// python: (True in {1: 'x'}) == True
	assert got_206 == true
	got_207 := contains(Value(new_set([Value(i64(1)), Value(i64(2))])!), Value(i64(1)))!
	// python: (1 in {1, 2}) == True
	assert got_207 == true
}

fn test_ops_mutation() {
	check_ops_mutation() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_mutation() ! {
	a := Value(new_list([Value(i64(1)), Value(i64(2)), Value(i64(3))]))
	b := a
	setitem(b, Value(i64(-1)), Value(i64(9)))!
	// python: exec_result("a=[1,2,3]; b=a; b[-1]=9", "repr(a)") == '[1, 2, 9]' 
	assert repr(a) == '[1, 2, 9]'
	delitem(b, Value(i64(-2)))!
	// python: exec_result("a=[1,2,9]; b=a; del b[-2]", "repr(a)") == '[1, 9]' 
	assert repr(a) == '[1, 9]'
	child := Value(new_list([Value(i64(1))]))
	repeated_list := mul(Value(new_list([child])), Value(i64(2)))!
	first := getitem(repeated_list, Value(i64(0)))!
	setitem(first, Value(i64(0)), Value(i64(8)))!
	// python: exec_result("a=[[1]]*2; a[0][0]=8", "repr(a)") == '[[8], [8]]' 
	assert repr(repeated_list) == '[[8], [8]]'
}

fn test_ops_python_errors() {
	check_ops_python_errors() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_python_errors() ! {
	got_211 := ops_test_error(fn () !Value {
		return truediv(Value(i64(1)), Value(i64(0)))!
	})
	// python: error_text(lambda: 1/0) == 'ZeroDivisionError|division by zero'
	assert got_211 == 'ZeroDivisionError|division by zero'
	got_212 := ops_test_error(fn () !Value {
		return truediv(Value(1.0), Value(i64(0)))!
	})
	// python: error_text(lambda: 1.0/0) == 'ZeroDivisionError|float division by zero'
	assert got_212 == 'ZeroDivisionError|float division by zero'
	got_213 := ops_test_error(fn () !Value {
		return floordiv(Value(i64(1)), Value(i64(0)))!
	})
	// python: error_text(lambda: 1//0) == 'ZeroDivisionError|integer division or modulo by zero'
	assert got_213 == 'ZeroDivisionError|integer division or modulo by zero'
	got_214 := ops_test_error(fn () !Value {
		return floordiv(Value(1.0), Value(i64(0)))!
	})
	// python: error_text(lambda: 1.0//0) == 'ZeroDivisionError|float floor division by zero'
	assert got_214 == 'ZeroDivisionError|float floor division by zero'
	got_215 := ops_test_error(fn () !Value {
		return mod(Value(i64(1)), Value(i64(0)))!
	})
	// python: error_text(lambda: 1%0) == 'ZeroDivisionError|integer modulo by zero'
	assert got_215 == 'ZeroDivisionError|integer modulo by zero'
	got_216 := ops_test_error(fn () !Value {
		return mod(Value(1.0), Value(i64(0)))!
	})
	// python: error_text(lambda: 1.0%0) == 'ZeroDivisionError|float modulo by zero'
	assert got_216 == 'ZeroDivisionError|float modulo by zero'
	got_217 := ops_test_error(fn () !Value {
		return pow(Value(i64(0)), Value(i64(-1)))!
	})
	// python: error_text(lambda: 0**-1) == 'ZeroDivisionError|0.0 cannot be raised to a negative power'
	assert got_217 == 'ZeroDivisionError|0.0 cannot be raised to a negative power'
	got_218 := ops_test_error(fn () !Value {
		return add(Value('a'), Value(i64(1)))!
	})
	// python: error_text(lambda: 'a'+1) == 'TypeError|can only concatenate str (not "int") to str'
	assert got_218 == 'TypeError|can only concatenate str (not "int") to str'
	got_219 := ops_test_error(fn () !Value {
		return add(Value(i64(1)), Value('a'))!
	})
	// python: error_text(lambda: 1+'a') == "TypeError|unsupported operand type(s) for +: 'int' and 'str'"
	assert got_219 == 'TypeError|unsupported operand type(s) for +: \'int\' and \'str\''
	got_220 := ops_test_error(fn () !Value {
		return add(Value(new_list([]Value{})), Value(new_tuple([]Value{})))!
	})
	// python: error_text(lambda: []+()) == 'TypeError|can only concatenate list (not "tuple") to list'
	assert got_220 == 'TypeError|can only concatenate list (not "tuple") to list'
	got_221 := ops_test_error(fn () !Value {
		return add(Value(new_tuple([]Value{})), Value(new_list([]Value{})))!
	})
	// python: error_text(lambda: ()+[]) == 'TypeError|can only concatenate tuple (not "list") to tuple'
	assert got_221 == 'TypeError|can only concatenate tuple (not "list") to tuple'
	got_222 := ops_test_error(fn () !Value {
		return add(Value([]u8{}), Value('x'))!
	})
	// python: error_text(lambda: b''+'x') == "TypeError|can't concat str to bytes"
	assert got_222 == 'TypeError|can\'t concat str to bytes'
	got_223 := ops_test_error(fn () !Value {
		return sub(Value('a'), Value(i64(1)))!
	})
	// python: error_text(lambda: 'a'-1) == "TypeError|unsupported operand type(s) for -: 'str' and 'int'"
	assert got_223 == 'TypeError|unsupported operand type(s) for -: \'str\' and \'int\''
	got_224 := ops_test_error(fn () !Value {
		return mul(Value('a'), Value(1.5))!
	})
	// python: error_text(lambda: 'a'*1.5) == "TypeError|can't multiply sequence by non-int of type 'float'"
	assert got_224 == 'TypeError|can\'t multiply sequence by non-int of type \'float\''
	got_225 := ops_test_error(fn () !Value {
		return neg(none_)!
	})
	// python: error_text(lambda: -None) == "TypeError|bad operand type for unary -: 'NoneType'"
	assert got_225 == 'TypeError|bad operand type for unary -: \'NoneType\''
	got_226 := ops_test_error(fn () !Value {
		return Value(lt(none_, Value(i64(1)))!)
	})
	// python: error_text(lambda: None<1) == "TypeError|'<' not supported between instances of 'NoneType' and 'int'"
	assert got_226 == 'TypeError|\'<\' not supported between instances of \'NoneType\' and \'int\''
	got_227 := ops_test_error(fn () !Value {
		return Value(le(none_, none_)!)
	})
	// python: error_text(lambda: None<=None) == "TypeError|'<=' not supported between instances of 'NoneType' and 'NoneType'"
	assert got_227 == 'TypeError|\'<=\' not supported between instances of \'NoneType\' and \'NoneType\''
	got_228 := ops_test_error(fn () !Value {
		return Value(contains(Value('abc'), Value(i64(1)))!)
	})
	// python: error_text(lambda: 1 in 'abc') == "TypeError|'in <string>' requires string as left operand, not int"
	assert got_228 == 'TypeError|\'in <string>\' requires string as left operand, not int'
	got_229 := ops_test_error(fn () !Value {
		return Value(contains(Value([u8(97)]), Value(i64(256)))!)
	})
	// python: error_text(lambda: 256 in b'a') == 'ValueError|byte must be in range(0, 256)'
	assert got_229 == 'ValueError|byte must be in range(0, 256)'
	got_230 := ops_test_error(fn () !Value {
		return Value(contains(Value([u8(97)]), Value(1.2))!)
	})
	// python: error_text(lambda: 1.2 in b'a') == "TypeError|a bytes-like object is required, not 'float'"
	assert got_230 == 'TypeError|a bytes-like object is required, not \'float\''
	got_231 := ops_test_error(fn () !Value {
		return Value(contains(none_, Value(i64(1)))!)
	})
	// python: error_text(lambda: 1 in None) == "TypeError|argument of type 'NoneType' is not iterable"
	assert got_231 == 'TypeError|argument of type \'NoneType\' is not iterable'
	got_232 := ops_test_error(fn () !Value {
		return Value(i64(len_(Value(i64(1)))!))
	})
	// python: error_text(lambda: len(1)) == "TypeError|object of type 'int' has no len()"
	assert got_232 == 'TypeError|object of type \'int\' has no len()'
	got_233 := ops_test_error(fn () !Value {
		return getitem(Value(new_list([]Value{})), Value(i64(0)))!
	})
	// python: error_text(lambda: [][0]) == 'IndexError|list index out of range'
	assert got_233 == 'IndexError|list index out of range'
	got_234 := ops_test_error(fn () !Value {
		return getitem(Value(new_tuple([]Value{})), Value(i64(0)))!
	})
	// python: error_text(lambda: ()[0]) == 'IndexError|tuple index out of range'
	assert got_234 == 'IndexError|tuple index out of range'
	got_235 := ops_test_error(fn () !Value {
		return getitem(Value('a'), Value(i64(2)))!
	})
	// python: error_text(lambda: 'a'[2]) == 'IndexError|string index out of range'
	assert got_235 == 'IndexError|string index out of range'
	got_236 := ops_test_error(fn () !Value {
		return getitem(Value([u8(97)]), Value(i64(2)))!
	})
	// python: error_text(lambda: b'a'[2]) == 'IndexError|index out of range'
	assert got_236 == 'IndexError|index out of range'
	got_237 := ops_test_error(fn () !Value {
		return getitem(Value('a'), Value('x'))!
	})
	// python: error_text(lambda: 'a'['x']) == "TypeError|string indices must be integers, not 'str'"
	assert got_237 == 'TypeError|string indices must be integers, not \'str\''
	got_238 := ops_test_error(fn () !Value {
		return getitem(Value(new_list([]Value{})), Value('x'))!
	})
	// python: error_text(lambda: []['x']) == 'TypeError|list indices must be integers or slices, not str'
	assert got_238 == 'TypeError|list indices must be integers or slices, not str'
	got_239 := ops_test_error(fn () !Value {
		return getitem(none_, Value(i64(0)))!
	})
	// python: error_text(lambda: None[0]) == "TypeError|'NoneType' object is not subscriptable"
	assert got_239 == 'TypeError|\'NoneType\' object is not subscriptable'
	got_240 := ops_test_error(fn () !Value {
		return getitem(Value(new_dict()), Value('missing'))!
	})
	// python: error_text(lambda: {}['missing']) == "KeyError|'missing'"
	assert got_240 == 'KeyError|\'missing\''
	got_241 := ops_test_error(fn () !Value {
		return getitem(Value(new_dict()), Value(i64(3)))!
	})
	// python: error_text(lambda: {}[3]) == 'KeyError|3'
	assert got_241 == 'KeyError|3'
	got_242 := ops_test_error(fn () !Value {
		return Value(hash_key(Value(new_list([]Value{})))!)
	})
	// python: error_text(lambda: hash([])) == "TypeError|unhashable type: 'list'"
	assert got_242 == 'TypeError|unhashable type: \'list\''
	got_243 := ops_test_error(fn () !Value {
		return getslice(Value(new_list([]Value{})), none, none, 0)!
	})
	// python: error_text(lambda: [][::0]) == 'ValueError|slice step cannot be zero'
	assert got_243 == 'ValueError|slice step cannot be zero'
	got_244 := ops_test_error(fn () !Value {
		setitem(Value(new_tuple([]Value{})), Value(i64(0)), none_)!
	return none_
	})
	// python: error_text(lambda: operator.setitem((),0,None)) == "TypeError|'tuple' object does not support item assignment"
	assert got_244 == 'TypeError|\'tuple\' object does not support item assignment'
	got_245 := ops_test_error(fn () !Value {
		delitem(Value(new_tuple([]Value{})), Value(i64(0)))!
	return none_
	})
	// python: error_text(lambda: operator.delitem((),0)) == "TypeError|'tuple' object doesn't support item deletion"
	assert got_245 == 'TypeError|\'tuple\' object doesn\'t support item deletion'
	got_246 := ops_test_error(fn () !Value {
		setitem(Value(new_list([]Value{})), Value(i64(1)), none_)!
	return none_
	})
	// python: error_text(lambda: operator.setitem([],1,None)) == 'IndexError|list assignment index out of range'
	assert got_246 == 'IndexError|list assignment index out of range'
	got_247 := ops_test_error(fn () !Value {
		delitem(Value(new_list([]Value{})), Value(i64(1)))!
	return none_
	})
	// python: error_text(lambda: operator.delitem([],1)) == 'IndexError|list assignment index out of range'
	assert got_247 == 'IndexError|list assignment index out of range'
}

fn test_ops_bounded_integer_contract() {
	check_ops_bounded_integer_contract() or {
		// harness: no unexpected result errors.
		assert false, err.msg()
	}
}

fn check_ops_bounded_integer_contract() ! {
	// Fatal representation failures run in a separate process in integer_differential.vsh.
	got_254 := mul(Value(int_min), Value(i64(1)))!
	// python: repr(-(2**63)) == '-9223372036854775808'
	assert repr(got_254) == '-9223372036854775808'
	got_255 := mul(Value(int_max), Value(i64(-1)))!
	// python: repr(-(2**63-1)) == '-9223372036854775807'
	assert repr(got_255) == '-9223372036854775807'
	got_256 := pow(Value(int_max), Value(i64(1)))!
	// python: repr((2**63-1)**1) == '9223372036854775807'
	assert repr(got_256) == '9223372036854775807'
	got_257 := pow(Value(i64(-2)), Value(i64(63)))!
	// python: repr((-2)**63) == '-9223372036854775808'
	assert repr(got_257) == '-9223372036854775808'
	got_258 := sub(Value(int_min), Value(int_min))!
	// python: repr(-(2**63)-(-(2**63))) == '0'
	assert repr(got_258) == '0'
}


fn ops_test_error(callback fn () !Value) string {
	_ = callback() or {
		if err is PyError { return err.class_name + '|' + err.msg() }
		return 'VError|' + err.msg()
	}
	return '<no error>'
}
fn ops_test_dict(keys []Value, values []Value) !Value {
	d := Value(new_dict())
	for i, key in keys { setitem(d, key, values[i])! }
	return d
}

fn test_signed_zero_regression() {
    check_signed_zero_regression() or { assert false, err.msg() }
}

fn check_signed_zero_regression() ! {
    // python: repr(-0.0) == '-0.0'
    assert repr(Value(-0.0)) == '-0.0'
    // python: repr(-(-0.0)) == '0.0'
    assert repr(neg(Value(-0.0))!) == '0.0'
    // python: repr(-(0.0)) == '-0.0'
    assert repr(neg(Value(0.0))!) == '-0.0'
    // python: repr((-0.0) * 2.0) == '-0.0'
    assert repr(mul(Value(-0.0), Value(2.0))!) == '-0.0'
    // python: repr((-0.0) * (-2.0)) == '0.0'
    assert repr(mul(Value(-0.0), Value(-2.0))!) == '0.0'
    // python: repr((-0.0) ** 3) == '-0.0'
    assert repr(pow(Value(-0.0), Value(i64(3)))!) == '-0.0'
    // python: repr((-0.0) ** 2) == '0.0'
    assert repr(pow(Value(-0.0), Value(i64(2)))!) == '0.0'
    // python: repr(-0.0 ** 2) == '-0.0'
    assert repr(neg(pow(Value(0.0), Value(i64(2)))!)!) == '-0.0'
}
