module pyrt

// box turns typed scalars, bytes, containers, and runtime handles into Value.
// Shared native list descriptors cross through a Sequence bridge without copying.
// Ordinary arrays and maps become new containers; native bytes are copied.
pub fn box[T](v T) Value {
	$if T is ?Value || T is ?string || T is ?bool || T is ?int || T is ?i64 || T is ?f64 || T is ?[]u8 || T is ?&List || T is ?&Dict || T is ?&Set || T is ?&Tuple || T is ?Instance || T is ?Sequence {
		if actual := v {
			return box(actual)
		}
		return none_
	} $else $if T is Value {
		return v
	} $else $if T is NoneType || T is Function || T is &List || T is &Dict || T is &Set || T is &Tuple {
		return Value(v)
	} $else $if T is Instance {
		return Value(Instance(v))
	} $else $if T is Sequence {
		$if T is ListMethods {
			return Value(Sequence(&ListBridge{ sequence: Sequence(v), methods: ListMethods(v) }))
		}
		return Value(Sequence(v))
	} $else $if T is bool {
		return Value(v)
	} $else $if T is $int {
		return Value(i64(v))
	} $else $if T is $float {
		return Value(f64(v))
	} $else $if T is string {
		return Value(v)
	} $else $if T is []u8 {
		return Value(v.clone())
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

// same_object compares runtime references by identity, retaining value equality only
// for scalar variants whose original object identity has already been erased.
pub fn same_object(a Value, b Value) bool {
	left := object_identity(a)
	right := object_identity(b)
	if left != 0 || right != 0 {
		return left != 0 && left == right
	}
	return a == b
}
