module pyrt

pub fn str(v Value) string {
	if v is string {
		return v
	}
	return repr(v)
}

pub fn repr(v Value) string {
	return repr_nested(v, []i64{}, 0)
}

fn repr_nested(v Value, ancestors []i64, depth int) string {
	// str/repr have non-result signatures, so they cannot propagate RecursionError.
	if depth > 256 {
		return '...'
	}
	whole := v
	match v {
		NoneType { return 'None' }
		bool { return if v { 'True' } else { 'False' } }
		i64 { return v.str() }
        int { return v.str() }
		f64 { return float_repr(v) }
		string { return quote_string(v) }
		[]u8 { return quote_bytes(v) }
		Function { return '<function ${v.name}>' }
		Instance { return '<${v.class_name()} object>' }
		&List, Sequence, &Tuple, &Dict, &Set {
			id := value_identity(whole)
			if id != 0 && id in ancestors {
				return match whole {
					&Dict { '{...}' }
					&Tuple { '(...)' }
					&Set { if whole.frozen { 'frozenset(...)' } else { 'set(...)' } }
					else { '[...]' }
				}
			}
			mut path := ancestors.clone()
			if id != 0 {
				path << id
			}
			mut parts := []string{}
			match whole {
				&Dict {
					for key_value in whole.keys {
						key := hash_key(key_value) or { return '<invalid dict>' }
						item := whole.values[key] or { return '<invalid dict>' }
						parts << repr_nested(key_value, path, depth + 1) + ': ' +
							repr_nested(item, path, depth + 1)
					}
					return '{' + parts.join(', ') + '}'
				}
				else {
					sequence_items := iter(whole) or { return '<sequence read error: ${err.msg()}>' }
					for item in sequence_items {
						parts << repr_nested(item, path, depth + 1)
					}
					if whole is &Tuple {
						if parts.len == 1 {
							return '(' + parts[0] + ',)'
						}
						return '(' + parts.join(', ') + ')'
					}
					if whole is &Set {
                        if whole.frozen {
                            if parts.len == 0 { return 'frozenset()' }
                            return 'frozenset({' + parts.join(', ') + '})'
                        }
						if parts.len == 0 { return 'set()' }
						return '{' + parts.join(', ') + '}'
					}
					return '[' + parts.join(', ') + ']'
				}
			}
		}
	}
}

// Strings entering this runtime must contain UTF-8 (surrogate code points may
// also be represented by their three-byte encoding). No locale API is used.
fn utf8_parts(s string) []string {
	mut out := []string{}
	mut i := 0
	for i < s.len {
		b := int(s[i])
		mut width := 1
		if b >= 192 && b < 224 {
			width = 2
		} else if b >= 224 && b < 240 {
			width = 3
		} else if b >= 240 && b < 248 {
			width = 4
		}
		if i + width > s.len {
			width = 1
		}
		out << s[i .. i + width]
		i = i + width
	}
	return out
}

fn unicode_point(part string) int {
	if part.len == 1 {
		return int(part[0])
	}
	if part.len == 2 {
		return (int(part[0]) - 192) * 64 + int(part[1]) - 128
	}
	if part.len == 3 {
		return (int(part[0]) - 224) * 4096 + (int(part[1]) - 128) * 64 + int(part[2]) - 128
	}
	return (int(part[0]) - 240) * 262144 + (int(part[1]) - 128) * 4096 +
		(int(part[2]) - 128) * 64 + int(part[3]) - 128
}

fn hex_fixed(value int, width int) string {
	digits := '0123456789abcdef'
	mut n := value
	mut out := ''
	for _ in 0 .. width {
		d := n % 16
		out = digits[d .. d + 1] + out
		n = n / 16
	}
	return out
}

fn unicode_printable(cp int) bool {
	mut lo := 0
	mut hi := nonprintable_ranges.len / 2
	for lo < hi {
		mid := (lo + hi) / 2
		if cp < nonprintable_ranges[mid * 2] {
			hi = mid
		} else if cp > nonprintable_ranges[mid * 2 + 1] {
			lo = mid + 1
		} else {
			return false
		}
	}
	return true
}

fn quote_string(s string) string {
	quote := if s.contains("'") && !s.contains('"') { '"' } else { "'" }
	mut out := quote
	for ch in utf8_parts(s) {
		cp := unicode_point(ch)
		if ch == quote {
			out = out + '\\' + ch
		} else if cp == 92 {
			out = out + '\\\\'
		} else if cp == 9 {
			out = out + '\\t'
		} else if cp == 10 {
			out = out + '\\n'
		} else if cp == 13 {
			out = out + '\\r'
		} else if unicode_printable(cp) {
			out = out + ch
		} else if cp < 256 {
			out = out + '\\x' + hex_fixed(cp, 2)
		} else if cp < 65536 {
			out = out + '\\u' + hex_fixed(cp, 4)
		} else {
			out = out + '\\U' + hex_fixed(cp, 8)
		}
	}
	return out + quote
}

fn quote_bytes(data []u8) string {
	mut has_single := false
	mut has_double := false
	for b in data {
		if b == 39 { has_single = true }
		if b == 34 { has_double = true }
	}
	quote := if has_single && !has_double { '"' } else { "'" }
	quote_byte := if has_single && !has_double { 34 } else { 39 }
	mut out := 'b' + quote
	for b in data {
		cp := int(b)
		if cp == quote_byte {
			out = out + '\\' + quote
		} else if cp == 92 {
			out = out + '\\\\'
		} else if cp == 9 {
			out = out + '\\t'
		} else if cp == 10 {
			out = out + '\\n'
		} else if cp == 13 {
			out = out + '\\r'
		} else if cp >= 32 && cp <= 126 {
			out = out + printable_ascii[cp - 32 .. cp - 31]
		} else {
			out = out + '\\x' + hex_fixed(cp, 2)
		}
	}
	return out + quote
}

// Small, unsigned arbitrary-precision integers, base 10^9, least limb first.
// These are PRIVATE formatting/division work space. Python integer Values
// remain bounded i64. Every limb operation fits in i64.
const limb_base = i64(1000000000)

fn big_magnitude(value i64) []i64 {
	mut out := []i64{}
	mut n := value
	for n != 0 {
		mut digit := n % limb_base
		if digit < 0 { digit = -digit }
		out << digit
		n = n / limb_base
	}
	if out.len == 0 { out << i64(0) }
	return out
}

fn big_compare(a []i64, b []i64) int {
	if a.len < b.len { return -1 }
	if a.len > b.len { return 1 }
	mut i := a.len - 1
	for i >= 0 {
		if a[i] < b[i] { return -1 }
		if a[i] > b[i] { return 1 }
		i = i - 1
	}
	return 0
}

fn big_multiply_small(a []i64, factor i64) []i64 {
	mut out := []i64{}
	mut carry := i64(0)
	for digit in a {
		n := digit * factor + carry
		out << n % limb_base
		carry = n / limb_base
	}
	for carry > 0 {
		out << carry % limb_base
		carry = carry / limb_base
	}
	for out.len > 1 && out.last() == 0 { _ = out.pop() }
	return out
}

fn big_add(a []i64, b []i64) []i64 {
	mut out := []i64{}
	n := if a.len > b.len { a.len } else { b.len }
	mut carry := i64(0)
	for i in 0 .. n {
		left := if i < a.len { a[i] } else { i64(0) }
		right := if i < b.len { b[i] } else { i64(0) }
		value := left + right + carry
		out << value % limb_base
		carry = value / limb_base
	}
	if carry != 0 { out << carry }
	return out
}

// Requires a >= b.
fn big_subtract(a []i64, b []i64) []i64 {
	mut out := []i64{}
	mut borrow := i64(0)
	for i in 0 .. a.len {
		right := if i < b.len { b[i] } else { i64(0) }
		mut value := a[i] - right - borrow
		borrow = 0
		if value < 0 {
			value = value + limb_base
			borrow = 1
		}
		out << value
	}
	for out.len > 1 && out.last() == 0 { _ = out.pop() }
	return out
}

fn big_times_power_two(a []i64, exponent int) []i64 {
	mut out := a.clone()
	for _ in 0 .. exponent { out = big_multiply_small(out, 2) }
	return out
}

fn float_is_nan(x f64) bool {
	return x != x
}

fn float_is_inf(x f64) bool {
	return x != 0.0 && x == x * 0.5
}

fn float_negative(x f64) bool {
	if x < 0.0 { return true }
	if x != 0.0 { return false }
	// Only sign-of-zero detection depends on V's formatter. Decimal digits do not.
	s := x.str()
	return s.len > 0 && s[0] == 45
}

fn zero_with_sign(negative bool) f64 {
	z := 0.0
	return if negative { -z } else { z }
}

// Shortest correctly rounded decimal generation using exact integer boundary
// intervals. No V float-to-decimal digits or libc/libm conversion are used.
// The even-significand boundary rule is IEEE-754 round-to-nearest, ties-to-even.
fn float_repr(value f64) string {
	if float_is_nan(value) { return 'nan' }
	negative := float_negative(value)
	prefix := if negative { '-' } else { '' }
	if float_is_inf(value) { return prefix + 'inf' }
	if value == 0.0 { return prefix + '0.0' }
	mut normalized := if negative { -value } else { value }
	mut binary_exponent := 0
	for normalized >= 2.0 {
		normalized = normalized * 0.5
		binary_exponent = binary_exponent + 1
	}
	for normalized < 1.0 {
		normalized = normalized * 2.0
		binary_exponent = binary_exponent - 1
	}
	mut mantissa := i64(normalized * 4503599627370496.0)
	mut unit_exponent := binary_exponent - 52
	if binary_exponent < -1022 {
		shift := -1022 - binary_exponent
		for _ in 0 .. shift { mantissa = mantissa / 2 }
		unit_exponent = -1074
	}
	asymmetric := binary_exponent > -1022 && mantissa == i64(4503599627370496)
	even := mantissa % 2 == 0
	factor := if asymmetric { i64(4) } else { i64(2) }
	mut numerator := big_multiply_small(big_magnitude(mantissa), factor)
	mut denominator := [factor]
	upper_digit := if asymmetric { i64(2) } else { i64(1) }
	mut upper_margin := [upper_digit]
	mut lower_margin := [i64(1)]
	if unit_exponent >= 0 {
		numerator = big_times_power_two(numerator, unit_exponent)
		upper_margin = big_times_power_two(upper_margin, unit_exponent)
		lower_margin = big_times_power_two(lower_margin, unit_exponent)
	} else {
		denominator = big_times_power_two(denominator, -unit_exponent)
	}
	mut decimal_exponent := 0
	for big_compare(numerator, big_multiply_small(denominator, 10)) >= 0 {
		denominator = big_multiply_small(denominator, 10)
		decimal_exponent = decimal_exponent + 1
	}
	for big_compare(numerator, denominator) < 0 {
		numerator = big_multiply_small(numerator, 10)
		upper_margin = big_multiply_small(upper_margin, 10)
		lower_margin = big_multiply_small(lower_margin, 10)
		decimal_exponent = decimal_exponent - 1
	}
	mut digits := []int{}
	for {
		mut digit := 0
		for big_compare(numerator, denominator) >= 0 {
			numerator = big_subtract(numerator, denominator)
			digit = digit + 1
		}
		low_cmp := big_compare(numerator, lower_margin)
		high_cmp := big_compare(big_add(numerator, upper_margin), denominator)
		low_ok := low_cmp < 0 || (low_cmp == 0 && even)
		high_ok := high_cmp > 0 || (high_cmp == 0 && even)
		digits << digit
		if low_ok || high_ok {
			middle := big_compare(big_multiply_small(numerator, 2), denominator)
			round_up := high_ok && (!low_ok || middle > 0 || (middle == 0 && digit % 2 != 0))
			if round_up {
				mut position := digits.len - 1
				for position >= 0 && digits[position] == 9 {
					digits[position] = 0
					position = position - 1
				}
				if position >= 0 {
					digits[position] = digits[position] + 1
				} else {
					mut replacement := [1]
					replacement << digits
					digits = replacement.clone()
					decimal_exponent = decimal_exponent + 1
				}
			}
			break
		}
		numerator = big_multiply_small(numerator, 10)
		upper_margin = big_multiply_small(upper_margin, 10)
		lower_margin = big_multiply_small(lower_margin, 10)
	}
	for digits.len > 1 && digits.last() == 0 { _ = digits.pop() }
	mut decimal := ''
	for digit in digits { decimal = decimal + digit.str() }
	if decimal_exponent < -4 || decimal_exponent >= 16 {
		mut significand := decimal[0 .. 1]
		if decimal.len > 1 { significand = significand + '.' + decimal[1 .. decimal.len] }
		exponent_sign := if decimal_exponent < 0 { '-' } else { '+' }
		exponent_magnitude := if decimal_exponent < 0 { -decimal_exponent } else { decimal_exponent }
		mut exponent_text := exponent_magnitude.str()
		if exponent_text.len < 2 { exponent_text = '0' + exponent_text }
		return prefix + significand + 'e' + exponent_sign + exponent_text
	}
	if decimal_exponent < 0 {
		mut padding := ''
		for _ in 0 .. -decimal_exponent - 1 { padding = padding + '0' }
		return prefix + '0.' + padding + decimal
	}
	point := decimal_exponent + 1
	if decimal.len <= point {
		mut padding := ''
		for _ in 0 .. point - decimal.len { padding = padding + '0' }
		return prefix + decimal + padding + '.0'
	}
	return prefix + decimal[0 .. point] + '.' + decimal[point .. decimal.len]
}

const printable_ascii = ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'

// Nonprintable intervals from CPython 3.13.5, Unicode 15.1.0.
// This is embedded DATA, not a dependency on Python or a Unicode library.
// Newly assigned characters in a newer Unicode release may print differently.
const nonprintable_ranges = [
	0, 31, 127, 160, 173, 173, 888, 889,
	896, 899, 907, 907, 909, 909, 930, 930,
	1328, 1328, 1367, 1368, 1419, 1420, 1424, 1424,
	1480, 1487, 1515, 1518, 1525, 1541, 1564, 1564,
	1757, 1757, 1806, 1807, 1867, 1868, 1970, 1983,
	2043, 2044, 2094, 2095, 2111, 2111, 2140, 2141,
	2143, 2143, 2155, 2159, 2191, 2199, 2274, 2274,
	2436, 2436, 2445, 2446, 2449, 2450, 2473, 2473,
	2481, 2481, 2483, 2485, 2490, 2491, 2501, 2502,
	2505, 2506, 2511, 2518, 2520, 2523, 2526, 2526,
	2532, 2533, 2559, 2560, 2564, 2564, 2571, 2574,
	2577, 2578, 2601, 2601, 2609, 2609, 2612, 2612,
	2615, 2615, 2618, 2619, 2621, 2621, 2627, 2630,
	2633, 2634, 2638, 2640, 2642, 2648, 2653, 2653,
	2655, 2661, 2679, 2688, 2692, 2692, 2702, 2702,
	2706, 2706, 2729, 2729, 2737, 2737, 2740, 2740,
	2746, 2747, 2758, 2758, 2762, 2762, 2766, 2767,
	2769, 2783, 2788, 2789, 2802, 2808, 2816, 2816,
	2820, 2820, 2829, 2830, 2833, 2834, 2857, 2857,
	2865, 2865, 2868, 2868, 2874, 2875, 2885, 2886,
	2889, 2890, 2894, 2900, 2904, 2907, 2910, 2910,
	2916, 2917, 2936, 2945, 2948, 2948, 2955, 2957,
	2961, 2961, 2966, 2968, 2971, 2971, 2973, 2973,
	2976, 2978, 2981, 2983, 2987, 2989, 3002, 3005,
	3011, 3013, 3017, 3017, 3022, 3023, 3025, 3030,
	3032, 3045, 3067, 3071, 3085, 3085, 3089, 3089,
	3113, 3113, 3130, 3131, 3141, 3141, 3145, 3145,
	3150, 3156, 3159, 3159, 3163, 3164, 3166, 3167,
	3172, 3173, 3184, 3190, 3213, 3213, 3217, 3217,
	3241, 3241, 3252, 3252, 3258, 3259, 3269, 3269,
	3273, 3273, 3278, 3284, 3287, 3292, 3295, 3295,
	3300, 3301, 3312, 3312, 3316, 3327, 3341, 3341,
	3345, 3345, 3397, 3397, 3401, 3401, 3408, 3411,
	3428, 3429, 3456, 3456, 3460, 3460, 3479, 3481,
	3506, 3506, 3516, 3516, 3518, 3519, 3527, 3529,
	3531, 3534, 3541, 3541, 3543, 3543, 3552, 3557,
	3568, 3569, 3573, 3584, 3643, 3646, 3676, 3712,
	3715, 3715, 3717, 3717, 3723, 3723, 3748, 3748,
	3750, 3750, 3774, 3775, 3781, 3781, 3783, 3783,
	3791, 3791, 3802, 3803, 3808, 3839, 3912, 3912,
	3949, 3952, 3992, 3992, 4029, 4029, 4045, 4045,
	4059, 4095, 4294, 4294, 4296, 4300, 4302, 4303,
	4681, 4681, 4686, 4687, 4695, 4695, 4697, 4697,
	4702, 4703, 4745, 4745, 4750, 4751, 4785, 4785,
	4790, 4791, 4799, 4799, 4801, 4801, 4806, 4807,
	4823, 4823, 4881, 4881, 4886, 4887, 4955, 4956,
	4989, 4991, 5018, 5023, 5110, 5111, 5118, 5119,
	5760, 5760, 5789, 5791, 5881, 5887, 5910, 5918,
	5943, 5951, 5972, 5983, 5997, 5997, 6001, 6001,
	6004, 6015, 6110, 6111, 6122, 6127, 6138, 6143,
	6158, 6158, 6170, 6175, 6265, 6271, 6315, 6319,
	6390, 6399, 6431, 6431, 6444, 6447, 6460, 6463,
	6465, 6467, 6510, 6511, 6517, 6527, 6572, 6575,
	6602, 6607, 6619, 6621, 6684, 6685, 6751, 6751,
	6781, 6782, 6794, 6799, 6810, 6815, 6830, 6831,
	6863, 6911, 6989, 6991, 7039, 7039, 7156, 7163,
	7224, 7226, 7242, 7244, 7305, 7311, 7355, 7356,
	7368, 7375, 7419, 7423, 7958, 7959, 7966, 7967,
	8006, 8007, 8014, 8015, 8024, 8024, 8026, 8026,
	8028, 8028, 8030, 8030, 8062, 8063, 8117, 8117,
	8133, 8133, 8148, 8149, 8156, 8156, 8176, 8177,
	8181, 8181, 8191, 8207, 8232, 8239, 8287, 8303,
	8306, 8307, 8335, 8335, 8349, 8351, 8385, 8399,
	8433, 8447, 8588, 8591, 9255, 9279, 9291, 9311,
	11124, 11125, 11158, 11158, 11508, 11512, 11558, 11558,
	11560, 11564, 11566, 11567, 11624, 11630, 11633, 11646,
	11671, 11679, 11687, 11687, 11695, 11695, 11703, 11703,
	11711, 11711, 11719, 11719, 11727, 11727, 11735, 11735,
	11743, 11743, 11870, 11903, 11930, 11930, 12020, 12031,
	12246, 12271, 12288, 12288, 12352, 12352, 12439, 12440,
	12544, 12548, 12592, 12592, 12687, 12687, 12772, 12782,
	12831, 12831, 42125, 42127, 42183, 42191, 42540, 42559,
	42744, 42751, 42955, 42959, 42962, 42962, 42964, 42964,
	42970, 42993, 43053, 43055, 43066, 43071, 43128, 43135,
	43206, 43213, 43226, 43231, 43348, 43358, 43389, 43391,
	43470, 43470, 43482, 43485, 43519, 43519, 43575, 43583,
	43598, 43599, 43610, 43611, 43715, 43738, 43767, 43776,
	43783, 43784, 43791, 43792, 43799, 43807, 43815, 43815,
	43823, 43823, 43884, 43887, 44014, 44015, 44026, 44031,
	55204, 55215, 55239, 55242, 55292, 63743, 64110, 64111,
	64218, 64255, 64263, 64274, 64280, 64284, 64311, 64311,
	64317, 64317, 64319, 64319, 64322, 64322, 64325, 64325,
	64451, 64466, 64912, 64913, 64968, 64974, 64976, 65007,
	65050, 65055, 65107, 65107, 65127, 65127, 65132, 65135,
	65141, 65141, 65277, 65280, 65471, 65473, 65480, 65481,
	65488, 65489, 65496, 65497, 65501, 65503, 65511, 65511,
	65519, 65531, 65534, 65535, 65548, 65548, 65575, 65575,
	65595, 65595, 65598, 65598, 65614, 65615, 65630, 65663,
	65787, 65791, 65795, 65798, 65844, 65846, 65935, 65935,
	65949, 65951, 65953, 65999, 66046, 66175, 66205, 66207,
	66257, 66271, 66300, 66303, 66340, 66348, 66379, 66383,
	66427, 66431, 66462, 66462, 66500, 66503, 66518, 66559,
	66718, 66719, 66730, 66735, 66772, 66775, 66812, 66815,
	66856, 66863, 66916, 66926, 66939, 66939, 66955, 66955,
	66963, 66963, 66966, 66966, 66978, 66978, 66994, 66994,
	67002, 67002, 67005, 67071, 67383, 67391, 67414, 67423,
	67432, 67455, 67462, 67462, 67505, 67505, 67515, 67583,
	67590, 67591, 67593, 67593, 67638, 67638, 67641, 67643,
	67645, 67646, 67670, 67670, 67743, 67750, 67760, 67807,
	67827, 67827, 67830, 67834, 67868, 67870, 67898, 67902,
	67904, 67967, 68024, 68027, 68048, 68049, 68100, 68100,
	68103, 68107, 68116, 68116, 68120, 68120, 68150, 68151,
	68155, 68158, 68169, 68175, 68185, 68191, 68256, 68287,
	68327, 68330, 68343, 68351, 68406, 68408, 68438, 68439,
	68467, 68471, 68498, 68504, 68509, 68520, 68528, 68607,
	68681, 68735, 68787, 68799, 68851, 68857, 68904, 68911,
	68922, 69215, 69247, 69247, 69290, 69290, 69294, 69295,
	69298, 69372, 69416, 69423, 69466, 69487, 69514, 69551,
	69580, 69599, 69623, 69631, 69710, 69713, 69750, 69758,
	69821, 69821, 69827, 69839, 69865, 69871, 69882, 69887,
	69941, 69941, 69960, 69967, 70007, 70015, 70112, 70112,
	70133, 70143, 70162, 70162, 70210, 70271, 70279, 70279,
	70281, 70281, 70286, 70286, 70302, 70302, 70314, 70319,
	70379, 70383, 70394, 70399, 70404, 70404, 70413, 70414,
	70417, 70418, 70441, 70441, 70449, 70449, 70452, 70452,
	70458, 70458, 70469, 70470, 70473, 70474, 70478, 70479,
	70481, 70486, 70488, 70492, 70500, 70501, 70509, 70511,
	70517, 70655, 70748, 70748, 70754, 70783, 70856, 70863,
	70874, 71039, 71094, 71095, 71134, 71167, 71237, 71247,
	71258, 71263, 71277, 71295, 71354, 71359, 71370, 71423,
	71451, 71452, 71468, 71471, 71495, 71679, 71740, 71839,
	71923, 71934, 71943, 71944, 71946, 71947, 71956, 71956,
	71959, 71959, 71990, 71990, 71993, 71994, 72007, 72015,
	72026, 72095, 72104, 72105, 72152, 72153, 72165, 72191,
	72264, 72271, 72355, 72367, 72441, 72447, 72458, 72703,
	72713, 72713, 72759, 72759, 72774, 72783, 72813, 72815,
	72848, 72849, 72872, 72872, 72887, 72959, 72967, 72967,
	72970, 72970, 73015, 73017, 73019, 73019, 73022, 73022,
	73032, 73039, 73050, 73055, 73062, 73062, 73065, 73065,
	73103, 73103, 73106, 73106, 73113, 73119, 73130, 73439,
	73465, 73471, 73489, 73489, 73531, 73533, 73562, 73647,
	73649, 73663, 73714, 73726, 74650, 74751, 74863, 74863,
	74869, 74879, 75076, 77711, 77811, 77823, 78896, 78911,
	78934, 82943, 83527, 92159, 92729, 92735, 92767, 92767,
	92778, 92781, 92863, 92863, 92874, 92879, 92910, 92911,
	92918, 92927, 92998, 93007, 93018, 93018, 93026, 93026,
	93048, 93052, 93072, 93759, 93851, 93951, 94027, 94030,
	94088, 94094, 94112, 94175, 94181, 94191, 94194, 94207,
	100344, 100351, 101590, 101631, 101641, 110575, 110580, 110580,
	110588, 110588, 110591, 110591, 110883, 110897, 110899, 110927,
	110931, 110932, 110934, 110947, 110952, 110959, 111356, 113663,
	113771, 113775, 113789, 113791, 113801, 113807, 113818, 113819,
	113824, 118527, 118574, 118575, 118599, 118607, 118724, 118783,
	119030, 119039, 119079, 119080, 119155, 119162, 119275, 119295,
	119366, 119487, 119508, 119519, 119540, 119551, 119639, 119647,
	119673, 119807, 119893, 119893, 119965, 119965, 119968, 119969,
	119971, 119972, 119975, 119976, 119981, 119981, 119994, 119994,
	119996, 119996, 120004, 120004, 120070, 120070, 120075, 120076,
	120085, 120085, 120093, 120093, 120122, 120122, 120127, 120127,
	120133, 120133, 120135, 120137, 120145, 120145, 120486, 120487,
	120780, 120781, 121484, 121498, 121504, 121504, 121520, 122623,
	122655, 122660, 122667, 122879, 122887, 122887, 122905, 122906,
	122914, 122914, 122917, 122917, 122923, 122927, 122990, 123022,
	123024, 123135, 123181, 123183, 123198, 123199, 123210, 123213,
	123216, 123535, 123567, 123583, 123642, 123646, 123648, 124111,
	124154, 124895, 124903, 124903, 124908, 124908, 124911, 124911,
	124927, 124927, 125125, 125126, 125143, 125183, 125260, 125263,
	125274, 125277, 125280, 126064, 126133, 126208, 126270, 126463,
	126468, 126468, 126496, 126496, 126499, 126499, 126501, 126502,
	126504, 126504, 126515, 126515, 126520, 126520, 126522, 126522,
	126524, 126529, 126531, 126534, 126536, 126536, 126538, 126538,
	126540, 126540, 126544, 126544, 126547, 126547, 126549, 126550,
	126552, 126552, 126554, 126554, 126556, 126556, 126558, 126558,
	126560, 126560, 126563, 126563, 126565, 126566, 126571, 126571,
	126579, 126579, 126584, 126584, 126589, 126589, 126591, 126591,
	126602, 126602, 126620, 126624, 126628, 126628, 126634, 126634,
	126652, 126703, 126706, 126975, 127020, 127023, 127124, 127135,
	127151, 127152, 127168, 127168, 127184, 127184, 127222, 127231,
	127406, 127461, 127491, 127503, 127548, 127551, 127561, 127567,
	127570, 127583, 127590, 127743, 128728, 128731, 128749, 128751,
	128765, 128767, 128887, 128890, 128986, 128991, 129004, 129007,
	129009, 129023, 129036, 129039, 129096, 129103, 129114, 129119,
	129160, 129167, 129198, 129199, 129202, 129279, 129620, 129631,
	129646, 129647, 129661, 129663, 129673, 129679, 129726, 129726,
	129734, 129741, 129756, 129759, 129769, 129775, 129785, 129791,
	129939, 129939, 129995, 130031, 130042, 131071, 173792, 173823,
	177978, 177983, 178206, 178207, 183970, 183983, 191457, 191471,
	192094, 194559, 195102, 196607, 201547, 201551, 205744, 917759,
	918000, 1114111,
]
