module pyrt

// Python integers are unbounded. This runtime's integer Values are signed i64;
// operations that would leave that range raise OverflowError BEFORE arithmetic.
const int_max = i64(9223372036854775807)
const int_min = i64(-9223372036854775807) - 1
const int_float_upper = 9223372036854775808.0
const int_float_lower = -9223372036854775808.0

fn is_integral(v Value) bool {
	return match v { i64, int, bool { true } else { false } }
}

fn is_numeric(v Value) bool {
	return match v { i64, int, bool, f64 { true } else { false } }
}

fn integral_value(v Value) i64 {
	return match v {
		i64 { v }
		int { i64(v) }
		bool { if v { i64(1) } else { i64(0) } }
		else { i64(0) }
	}
}

fn numeric_float(v Value) f64 {
	return match v {
		f64 { v }
		i64 { f64(v) }
		int { f64(v) }
		bool { if v { 1.0 } else { 0.0 } }
		else { 0.0 }
	}
}

fn integer_overflow() IError {
	return raise('OverflowError', 'integer result exceeds signed 64-bit range')
}

fn checked_add(a i64, b i64) !i64 {
	if (b > 0 && a > int_max - b) || (b < 0 && a < int_min - b) {
		return integer_overflow()
	}
	return a + b
}

fn checked_subtract(a i64, b i64) !i64 {
	if (b > 0 && a < int_min + b) || (b < 0 && a > int_max + b) {
		return integer_overflow()
	}
	return a - b
}

fn checked_multiply(a i64, b i64) !i64 {
	if a == 0 || b == 0 { return i64(0) }
	if a > 0 {
		if (b > 0 && a > int_max / b) || (b < 0 && b < int_min / a) {
			return integer_overflow()
		}
	} else {
		if (b > 0 && a < int_min / b) || (b < 0 && a < int_max / b) {
			return integer_overflow()
		}
	}
	return a * b
}

fn binary_error(symbol string, a Value, b Value) IError {
	return raise('TypeError', "unsupported operand type(s) for ${symbol}: '${type_name(a)}' and '${type_name(b)}'")
}

fn is_list_value(v Value) bool {
	return match v { &List, Sequence { true } else { false } }
}

fn is_repeatable(v Value) bool {
	return match v { &List, Sequence, &Tuple, string, []u8 { true } else { false } }
}

pub fn add(a Value, b Value) !Value {
	if is_integral(a) && is_integral(b) {
		n := checked_add(integral_value(a), integral_value(b))!
		return Value(n)
	}
	if is_numeric(a) && is_numeric(b) { return Value(numeric_float(a) + numeric_float(b)) }
	if a is string {
		if b is string { return Value(a + b) }
		return raise('TypeError', 'can only concatenate str (not "${type_name(b)}") to str')
	}
	if a is []u8 {
		if b is []u8 {
			mut out := a.clone()
			out << b
			return Value(out)
		}
		return raise('TypeError', "can't concat ${type_name(b)} to bytes")
	}
	if is_list_value(a) {
		if is_list_value(b) {
			mut joined_items := iter(a)!
			joined_items << iter(b)!
			return Value(new_list(joined_items))
		}
		return raise('TypeError', 'can only concatenate list (not "${type_name(b)}") to list')
	}
	if a is &Tuple {
		if b is &Tuple {
			mut joined_items := a.items.clone()
			joined_items << b.items
			return Value(new_tuple(joined_items))
		}
		return raise('TypeError', 'can only concatenate tuple (not "${type_name(b)}") to tuple')
	}
	return binary_error('+', a, b)
}

pub fn sub(a Value, b Value) !Value {
	if is_integral(a) && is_integral(b) {
		n := checked_subtract(integral_value(a), integral_value(b))!
		return Value(n)
	}
	if is_numeric(a) && is_numeric(b) { return Value(numeric_float(a) - numeric_float(b)) }
	if a is &Set && b is &Set {
		mut set_difference_items := []Value{}
		for item in a.items {
			key := hash_key(item)!
			if key !in b.index { set_difference_items << item }
		}
		if a.frozen { return frozenset_of(set_difference_items)! }
        return Value(new_set(set_difference_items)!)
	}
	return binary_error('-', a, b)
}

fn repeated(v Value, count i64) !Value {
	n := len_(v)!
	mut repeat_count := count
	if repeat_count < 0 { repeat_count = 0 }
	if n != 0 && repeat_count > int_max / i64(n) {
		return raise('OverflowError', 'repeated sequence is too long')
	}
	// Repeating an empty sequence must not loop count times.
	if n == 0 { repeat_count = 0 }
	if v is string {
		mut out := ''
		for _ in 0 .. int(repeat_count) { out = out + v }
		return Value(out)
	}
	if v is []u8 {
		mut out := []u8{}
		for _ in 0 .. int(repeat_count) { out << v }
		return Value(out)
	}
	source_items := iter(v)!
	mut out := []Value{}
	for _ in 0 .. int(repeat_count) { out << source_items }
	if v is &Tuple { return Value(new_tuple(out)) }
	return Value(new_list(out))
}

pub fn mul(a Value, b Value) !Value {
	if is_integral(a) && is_integral(b) {
		n := checked_multiply(integral_value(a), integral_value(b))!
		return Value(n)
	}
	if is_numeric(a) && is_numeric(b) { return Value(numeric_float(a) * numeric_float(b)) }
	if is_repeatable(a) {
		if is_integral(b) { return repeated(a, integral_value(b))! }
		return raise('TypeError', "can't multiply sequence by non-int of type '${type_name(b)}'")
	}
	if is_repeatable(b) {
		if is_integral(a) { return repeated(b, integral_value(a))! }
		return raise('TypeError', "can't multiply sequence by non-int of type '${type_name(a)}'")
	}
	return binary_error('*', a, b)
}

// Exact rational rounding avoids the double rounding in f64(a) / f64(b).
// The ratio of two nonzero i64 values is always a normal, finite f64.
fn integer_ratio(a i64, b i64) f64 {
	negative := (a < 0) != (b < 0)
	if a == 0 { return zero_with_sign(negative) }
	mut numerator := big_magnitude(a)
	mut denominator := big_magnitude(b)
	mut exponent := 0
	for big_compare(numerator, denominator) < 0 {
		numerator = big_multiply_small(numerator, 2)
		exponent = exponent - 1
	}
	for big_compare(numerator, big_multiply_small(denominator, 2)) >= 0 {
		denominator = big_multiply_small(denominator, 2)
		exponent = exponent + 1
	}
	numerator = big_subtract(numerator, denominator)
	mut mantissa := i64(1)
	for _ in 0 .. 52 {
		numerator = big_multiply_small(numerator, 2)
		mantissa = mantissa * 2
		if big_compare(numerator, denominator) >= 0 {
			numerator = big_subtract(numerator, denominator)
			mantissa = mantissa + 1
		}
	}
	comparison := big_compare(big_multiply_small(numerator, 2), denominator)
	if comparison > 0 || (comparison == 0 && mantissa % 2 != 0) {
		mantissa = mantissa + 1
	}
	mut result := f64(mantissa)
	exponent = exponent - 52
	for exponent > 0 { result = result * 2.0
		 exponent = exponent - 1 }
	for exponent < 0 { result = result * 0.5
		 exponent = exponent + 1 }
	return if negative { -result } else { result }
}

pub fn truediv(a Value, b Value) !Value {
	if !is_numeric(a) || !is_numeric(b) { return binary_error('/', a, b) }
	if is_integral(a) && is_integral(b) {
		denominator := integral_value(b)
		if denominator == 0 { return raise('ZeroDivisionError', 'division by zero') }
		return Value(integer_ratio(integral_value(a), denominator))
	}
	denominator := numeric_float(b)
	if denominator == 0.0 { return raise('ZeroDivisionError', 'float division by zero') }
	return Value(numeric_float(a) / denominator)
}

struct FloatDivmod {
	quotient  f64
	remainder f64
}

fn float_floor(x f64) f64 {
	if float_is_nan(x) || float_is_inf(x) || x == 0.0 || x >= 4503599627370496.0 || x <= -4503599627370496.0 {
		return x
	}
	truncated := f64(i64(x))
	return if truncated > x { truncated - 1.0 } else { truncated }
}

// Exact binary reduction, replacing the unavailable libm fmod entry point.
// Each subtraction is between nearby nonnegative binary floats and is exact.
fn float_remainder(a f64, b f64) f64 {
	if float_is_nan(a) { return a }
	if float_is_nan(b) { return b }
	if float_is_inf(a) { return a - a }
	if float_is_inf(b) { return a }
	left := if a < 0.0 { -a } else { a }
	right := if b < 0.0 { -b } else { b }
	if left < right { return a }
	mut scaled := right
	for scaled <= left * 0.5 { scaled = scaled * 2.0 }
	mut result := left
	for {
		if result >= scaled { result = result - scaled }
		if scaled == right { break }
		scaled = scaled * 0.5
	}
	return if float_negative(a) { -result } else { result }
}

fn float_divmod(a f64, b f64) FloatDivmod {
	mut remainder := float_remainder(a, b)
	mut quotient := (a - remainder) / b
	if remainder != 0.0 {
		if (b < 0.0) != (remainder < 0.0) {
			remainder = remainder + b
			quotient = quotient - 1.0
		}
	} else {
		remainder = zero_with_sign(float_negative(b))
	}
	mut floored := quotient
	if quotient != 0.0 {
		floored = float_floor(quotient)
		if quotient - floored > 0.5 { floored = floored + 1.0 }
	} else {
		floored = zero_with_sign(float_negative(a) != float_negative(b))
	}
	return FloatDivmod{quotient: floored, remainder: remainder}
}

pub fn floordiv(a Value, b Value) !Value {
	if !is_numeric(a) || !is_numeric(b) { return binary_error('//', a, b) }
	if is_integral(a) && is_integral(b) {
		left := integral_value(a)
		right := integral_value(b)
		if right == 0 { return raise('ZeroDivisionError', 'integer division or modulo by zero') }
		if left == int_min && right == -1 { return integer_overflow() }
		mut quotient := left / right
		remainder := left % right
		if remainder != 0 && (remainder < 0) != (right < 0) { quotient = quotient - 1 }
		return Value(quotient)
	}
	right := numeric_float(b)
	if right == 0.0 { return raise('ZeroDivisionError', 'float floor division by zero') }
	out := float_divmod(numeric_float(a), right)
	return Value(out.quotient)
}

pub fn mod(a Value, b Value) !Value {
	if a is string {
		return raise('NotImplementedError', 'string percent formatting is not implemented')
	}
	if !is_numeric(a) || !is_numeric(b) { return binary_error('%', a, b) }
	if is_integral(a) && is_integral(b) {
		left := integral_value(a)
		right := integral_value(b)
		if right == 0 { return raise('ZeroDivisionError', 'integer modulo by zero') }
		if left == int_min && right == -1 { return Value(i64(0)) }
		mut remainder := left % right
		if remainder != 0 && (remainder < 0) != (right < 0) { remainder = remainder + right }
		return Value(remainder)
	}
	right := numeric_float(b)
	if right == 0.0 { return raise('ZeroDivisionError', 'float modulo by zero') }
	out := float_divmod(numeric_float(a), right)
	return Value(out.remainder)
}

fn infinity() f64 {
	largest := 1.7976931348623157e308
	return largest + largest
}

// Floating powers with integral exponents use multiplication, NOT CPython's
// libm pow. Rounding can therefore differ. Fractional finite exponents are
// explicitly unsupported rather than silently approximated; complex Values
// are outside the requested Value representation.
pub fn pow(a Value, b Value) !Value {
	if !is_numeric(a) || !is_numeric(b) { return binary_error('** or pow()', a, b) }
	if is_integral(a) && is_integral(b) && integral_value(b) >= 0 {
		mut exponent := integral_value(b)
		mut base := integral_value(a)
		mut result := i64(1)
		for exponent > 0 {
			if exponent % 2 != 0 { result = checked_multiply(result, base)! }
			exponent = exponent / 2
			if exponent != 0 { base = checked_multiply(base, base)! }
		}
		return Value(result)
	}
	base_value := numeric_float(a)
	exponent_value := numeric_float(b)
	if exponent_value == 0.0 || base_value == 1.0 { return Value(1.0) }
	if float_is_nan(exponent_value) { return Value(exponent_value) }
	if float_is_nan(base_value) { return Value(base_value) }
	if float_is_inf(exponent_value) {
		magnitude := if base_value < 0.0 { -base_value } else { base_value }
		if magnitude == 1.0 { return Value(1.0) }
		if (magnitude > 1.0) == (exponent_value > 0.0) { return Value(infinity()) }
		return Value(0.0)
	}
	if base_value == 0.0 && exponent_value < 0.0 {
		return raise('ZeroDivisionError', '0.0 cannot be raised to a negative power')
	}
	mut exponent := i64(0)
	if is_integral(b) {
		exponent = integral_value(b)
	} else {
		if exponent_value < int_float_lower || exponent_value >= int_float_upper || float_floor(exponent_value) != exponent_value {
			return raise('NotImplementedError', 'fractional or out-of-i64-range float exponent is not implemented')
		}
		exponent = i64(exponent_value)
	}
	if float_is_inf(base_value) {
		negative := base_value < 0.0 && exponent % 2 != 0
		if exponent < 0 { return Value(zero_with_sign(negative)) }
		return Value(if negative { -infinity() } else { infinity() })
	}
	mut base := base_value
	if exponent < 0 { base = 1.0 / base }
	mut result := 1.0
	// Dividing a negative exponent toward zero avoids negating INT64_MIN.
	for exponent != 0 {
		if exponent % 2 != 0 { result = result * base }
		exponent = exponent / 2
		if exponent != 0 { base = base * base }
	}
	if float_is_inf(result) {
		return raise('OverflowError', "(34, 'Numerical result out of range')")
	}
	return Value(result)
}

pub fn neg(v Value) !Value {
	if is_integral(v) {
		n := integral_value(v)
		if n == int_min { return integer_overflow() }
		return Value(-n)
	}
	if v is f64 { return Value(-v) }
	return raise('TypeError', "bad operand type for unary -: '${type_name(v)}'")
}

// -1, 0, +1; 2 means unordered (NaN). Never round an i64 into f64 to compare it.
fn integral_float_compare(integer i64, floating f64) int {
	if float_is_nan(floating) { return 2 }
	if floating >= int_float_upper { return -1 }
	if floating < int_float_lower { return 1 }
	truncated := i64(floating)
	if integer < truncated { return -1 }
	if integer > truncated { return 1 }
	converted := f64(truncated)
	if converted < floating { return -1 }
	if converted > floating { return 1 }
	return 0
}

fn numeric_compare(a Value, b Value) int {
	if is_integral(a) && is_integral(b) {
		left := integral_value(a)
		right := integral_value(b)
		if left < right { return -1 }
		if left > right { return 1 }
		return 0
	}
	if is_integral(a) { return integral_float_compare(integral_value(a), numeric_float(b)) }
	if is_integral(b) {
		result := integral_float_compare(integral_value(b), numeric_float(a))
		return if result == 2 { 2 } else { -result }
	}
	left := numeric_float(a)
	right := numeric_float(b)
	if float_is_nan(left) || float_is_nan(right) { return 2 }
	if left < right { return -1 }
	if left > right { return 1 }
	return 0
}

fn bytes_compare(a []u8, b []u8) int {
	limit := if a.len < b.len { a.len } else { b.len }
	for i in 0 .. limit {
		if a[i] < b[i] { return -1 }
		if a[i] > b[i] { return 1 }
	}
	if a.len < b.len { return -1 }
	if a.len > b.len { return 1 }
	return 0
}

fn strings_compare(a string, b string) int {
	limit := if a.len < b.len { a.len } else { b.len }
	for i in 0 .. limit {
		if a[i] < b[i] { return -1 }
		if a[i] > b[i] { return 1 }
	}
	if a.len < b.len { return -1 }
	if a.len > b.len { return 1 }
	return 0
}

pub fn eq(a Value, b Value) bool {
	return equal_nested(a, b, 0)
}

fn equal_nested(a Value, b Value, depth int) bool {
	if is_numeric(a) && is_numeric(b) { return numeric_compare(a, b) == 0 }
	if depth > 256 { return false }
	left_id := value_identity(a)
	right_id := value_identity(b)
	if left_id != 0 && left_id == right_id { return true }
	if is_list_value(a) && is_list_value(b) {
		left := iter(a) or { return false }
		right := iter(b) or { return false }
		return items_equal(left, right, depth + 1)
	}
	match a {
		NoneType { return b is NoneType }
		string { if b is string { return a == b } }
		[]u8 { if b is []u8 { return bytes_compare(a, b) == 0 } }
		&Tuple { if b is &Tuple { return items_equal(a.items, b.items, depth + 1) } }
		&Dict {
			if b is &Dict {
				if a.values.len != b.values.len { return false }
				for key, value in a.values {
					other := b.values[key] or { return false }
					if !equal_nested(value, other, depth + 1) { return false }
				}
				return true
			}
		}
		&Set {
			if b is &Set {
				return a.index.len == b.index.len && set_subset(a, b)
			}
		}
		else {}
	}
	return false
}

fn items_equal(a []Value, b []Value, depth int) bool {
	if a.len != b.len { return false }
	for i in 0 .. a.len {
		if !equal_nested(a[i], b[i], depth) { return false }
	}
	return true
}

fn set_subset(a &Set, b &Set) bool {
	for key, _ in a.index {
		if key !in b.index { return false }
	}
	return true
}

fn relation(comparison int, symbol string) bool {
	if comparison == 2 { return false }
	return match symbol {
		'<' { comparison < 0 }
		'<=' { comparison <= 0 }
		'>' { comparison > 0 }
		'>=' { comparison >= 0 }
		else { false }
	}
}

fn items_ordered(a []Value, b []Value, symbol string, depth int) !bool {
	limit := if a.len < b.len { a.len } else { b.len }
	for i in 0 .. limit {
		if !equal_nested(a[i], b[i], depth + 1) {
			return ordered_nested(a[i], b[i], symbol, depth + 1)!
		}
	}
	comparison := if a.len < b.len { -1 } else { if a.len > b.len { 1 } else { 0 } }
	return relation(comparison, symbol)
}

fn ordered_nested(a Value, b Value, symbol string, depth int) !bool {
	if depth > 256 { return raise('RecursionError', 'maximum recursion depth exceeded in comparison') }
	if is_numeric(a) && is_numeric(b) { return relation(numeric_compare(a, b), symbol) }
	if a is string && b is string { return relation(strings_compare(a, b), symbol) }
	if a is []u8 && b is []u8 { return relation(bytes_compare(a, b), symbol) }
	if is_list_value(a) && is_list_value(b) {
		return items_ordered(iter(a)!, iter(b)!, symbol, depth)!
	}
	if a is &Tuple && b is &Tuple { return items_ordered(a.items, b.items, symbol, depth)! }
	if a is &Set && b is &Set {
		return match symbol {
			'<' { a.index.len < b.index.len && set_subset(a, b) }
			'<=' { set_subset(a, b) }
			'>' { a.index.len > b.index.len && set_subset(b, a) }
			'>=' { set_subset(b, a) }
			else { false }
		}
	}
	return raise('TypeError', "'${symbol}' not supported between instances of '${type_name(a)}' and '${type_name(b)}'")
}

pub fn lt(a Value, b Value) !bool { return ordered_nested(a, b, '<', 0)! }
pub fn le(a Value, b Value) !bool { return ordered_nested(a, b, '<=', 0)! }
pub fn gt(a Value, b Value) !bool { return ordered_nested(a, b, '>', 0)! }
pub fn ge(a Value, b Value) !bool { return ordered_nested(a, b, '>=', 0)! }

pub fn hash_key(v Value) !string {
	return hash_nested(v, 0)!
}

fn hash_nested(v Value, depth int) !string {
	if depth > 256 { return raise('RecursionError', 'maximum recursion depth exceeded while hashing a tuple') }
	if is_integral(v) { return 'n' + integral_value(v).str() }
	match v {
		NoneType { return 'none' }
		string { return 's' + v }
		[]u8 {
			mut out := 'b'
			for byte in v { out = out + hex_fixed(int(byte), 2) }
			return out
		}
		f64 {
			if float_is_nan(v) {
				// Scalar f64 Values have no object identity. Collapsing distinct
				// NaNs into one key would silently lose data; reject instead.
				return raise('ValueError', 'NaN keys require object identity, unavailable for scalar float Values')
			}
			if v >= int_float_lower && v < int_float_upper {
				integer := i64(v)
				if f64(integer) == v { return 'n' + integer.str() }
			}
			return 'f' + float_repr(v)
		}
		&Set {
            if !v.frozen { return raise('TypeError', "unhashable type: 'set'") }
            mut members := []string{}
            for item in v.items { members << hash_nested(item, depth + 1)! }
            members.sort()
            mut out := 'F'
            for member in members {
                out = out + member.len.str() + ':' + member
            }
            return out
        }
		&Tuple {
			mut out := 't'
			for item in v.items {
				key := hash_nested(item, depth + 1)!
				out = out + key.len.str() + ':' + key
			}
			return out
		}
		else { return raise('TypeError', "unhashable type: '${type_name(v)}'") }
	}
}

fn bytes_contain(haystack []u8, needle []u8) bool {
	if needle.len == 0 { return true }
	if needle.len > haystack.len { return false }
	limit := haystack.len - needle.len + 1
	for i in 0 .. limit {
		mut equal := true
		for j in 0 .. needle.len {
			if haystack[i + j] != needle[j] { equal = false
				 break }
		}
		if equal { return true }
	}
	return false
}

pub fn contains(container Value, item Value) !bool {
	match container {
		&Dict {
			key := hash_key(item)!
			return key in container.values
		}
		&Set {
			key := hash_key(item)!
			return key in container.index
		}
		string {
			if item is string { return container.contains(item) }
			return raise('TypeError', "'in <string>' requires string as left operand, not ${type_name(item)}")
		}
		[]u8 {
			if is_integral(item) {
				n := integral_value(item)
				if n < 0 || n > 255 { return raise('ValueError', 'byte must be in range(0, 256)') }
				for byte in container { if i64(byte) == n { return true } }
				return false
			}
			if item is []u8 { return bytes_contain(container, item) }
			return raise('TypeError', "a bytes-like object is required, not '${type_name(item)}'")
		}
		&List, Sequence, &Tuple {
			for value in iter(container)! { if eq(value, item) { return true } }
			return false
		}
		else { return raise('TypeError', "argument of type '${type_name(container)}' is not iterable") }
	}
}

fn checked_index(i i64, n int, message string) !int {
	j := if i < 0 { i + i64(n) } else { i }
	if j < 0 || j >= i64(n) { return raise('IndexError', message) }
	return int(j)
}

fn index_type_error(kind string, key Value) IError {
	if kind == 'str' {
		return raise('TypeError', "string indices must be integers, not '${type_name(key)}'")
	}
	name := if kind == 'bytes' { 'byte' } else { kind }
	return raise('TypeError', '${name} indices must be integers or slices, not ${type_name(key)}')
}

pub fn getitem(container Value, key Value) !Value {
	match container {
		&Dict {
			hash := hash_key(key)!
			return container.values[hash] or { return key_error(key) }
		}
		&List {
			if !is_integral(key) { return index_type_error('list', key) }
			i := checked_index(integral_value(key), container.items.len, 'list index out of range')!
			return container.items[i]
		}
		Sequence {
			if !is_integral(key) { return index_type_error('list', key) }
			i := checked_index(integral_value(key), container.len(), 'list index out of range')!
			return container.get(i)!
		}
		&Tuple {
			if !is_integral(key) { return index_type_error('tuple', key) }
			i := checked_index(integral_value(key), container.items.len, 'tuple index out of range')!
			return container.items[i]
		}
		string {
			if !is_integral(key) { return index_type_error('str', key) }
			parts := utf8_parts(container)
			i := checked_index(integral_value(key), parts.len, 'string index out of range')!
			return Value(parts[i])
		}
		[]u8 {
			if !is_integral(key) { return index_type_error('bytes', key) }
			i := checked_index(integral_value(key), container.len, 'index out of range')!
			return Value(i64(container[i]))
		}
		else { return raise('TypeError', "'${type_name(container)}' object is not subscriptable") }
	}
}

pub fn setitem(container Value, key Value, value Value) ! {
	match container {
		&Dict {
			hash := hash_key(key)!
			unsafe {
				if hash !in container.values { container.keys << key }
				container.values[hash] = value
			}
			return
		}
		&List {
			if !is_integral(key) { return index_type_error('list', key) }
			i := checked_index(integral_value(key), container.items.len, 'list assignment index out of range')!
			unsafe { container.items[i] = value }
			return
		}
		Sequence {
			if !is_integral(key) { return index_type_error('list', key) }
			i := checked_index(integral_value(key), container.len(), 'list assignment index out of range')!
			mut sequence := unsafe { container }
			sequence.set(i, value)!
			return
		}
		else { return raise('TypeError', "'${type_name(container)}' object does not support item assignment") }
	}
}

pub fn delitem(container Value, key Value) ! {
	match container {
		&Dict {
			hash := hash_key(key)!
			if hash !in container.values { return key_error(key) }
			mut remaining_keys := []Value{}
			mut remaining_values := map[string]Value{}
			for old in container.keys {
				old_hash := hash_key(old)!
				if old_hash != hash {
					remaining_keys << old
					remaining_values[old_hash] = container.values[old_hash] or { none_ }
				}
			}
			unsafe {
				container.keys = remaining_keys.clone()
				container.values = remaining_values
			}
			return
		}
		&List {
			if !is_integral(key) { return index_type_error('list', key) }
			i := checked_index(integral_value(key), container.items.len, 'list assignment index out of range')!
			mut remaining_items := []Value{}
			for j, old in container.items { if j != i { remaining_items << old } }
			unsafe { container.items = remaining_items.clone() }
			return
		}
		Sequence {
			if !is_integral(key) { return index_type_error('list', key) }
			i := checked_index(integral_value(key), container.len(), 'list assignment index out of range')!
			mut sequence := unsafe { container }
			sequence.delete(i)!
			return
		}
		else { return raise('TypeError', "'${type_name(container)}' object doesn't support item deletion") }
	}
}

fn slice_indices(n int, lo ?int, hi ?int, step ?int) ![]int {
	stride := step or { 1 }
	if stride == 0 { return raise('ValueError', 'slice step cannot be zero') }
	mut start := if stride > 0 { 0 } else { n - 1 }
	mut stop := if stride > 0 { n } else { -1 }
	if value := lo {
		start = value
		if start < 0 { start = start + n }
		if stride > 0 {
			if start < 0 { start = 0 }
			if start > n { start = n }
		} else {
			if start < 0 { start = -1 }
			if start >= n { start = n - 1 }
		}
	}
	if value := hi {
		stop = value
		if stop < 0 { stop = stop + n }
		if stride > 0 {
			if stop < 0 { stop = 0 }
			if stop > n { stop = n }
		} else {
			if stop < 0 { stop = -1 }
			if stop >= n { stop = n - 1 }
		}
	}
	mut out := []int{}
	mut i := start
	if stride > 0 {
		for i < stop {
			out << i
			if stride >= stop - i { break }
			i = i + stride
		}
	} else {
		for i > stop {
			out << i
			if stride <= stop - i { break }
			i = i + stride
		}
	}
	return out
}

// A slice is a separate lowered operation: a slice object is not a Value.
// These bounds are V options, not Python None Values.
pub fn getslice(v Value, lo ?int, hi ?int, step ?int) !Value {
	if !is_repeatable(v) {
		return raise('NotImplementedError', 'slicing is implemented only for builtin sequences')
	}
	n := len_(v)!
	indices := slice_indices(n, lo, hi, step)!
	if v is string {
		parts := utf8_parts(v)
		mut out := []string{}
		for i in indices { out << parts[i] }
		return Value(out.join(''))
	}
	if v is []u8 {
		mut out := []u8{}
		for i in indices { out << v[i] }
		return Value(out)
	}
	mut sliced_items := []Value{}
	for i in indices { sliced_items << getitem(v, Value(i64(i)))! }
	if v is &Tuple { return Value(new_tuple(sliced_items)) }
	return Value(new_list(sliced_items))
}
