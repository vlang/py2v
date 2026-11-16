module pyrt

// box turns a typed V value into a Value: numbers, bool, string, bytes, a Value itself,
// and arrays and string-keyed maps of those (as a new list or dict).
pub fn box[T](v T) Value {
	$if T is Value {
		return v
	} $else $if T is bool {
		return Value(v)
	} $else $if T is $int {
		return Value(i64(v))
	} $else $if T is $float {
		return Value(f64(v))
	} $else $if T is string {
		return Value(v)
	} $else $if T is $map {
		mut d := new_dict()
		for key, item in v {
			setitem(Value(d), box(key), box(item)) or { panic(err) }
		}
		return Value(d)
	} $else $if T is $array {
		mut items := []Value{cap: v.len}
		for item in v {
			items << box(item)
		}
		return Value(&List{
			items: items
		})
	} $else {
		$compile_error('pyrt.box: no Value form for this type')
	}
}
