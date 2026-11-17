module pyrt

// map_get reads after the key and default have been evaluated, as dict.get does.
pub fn map_get[T](mapping &map[string]T, key string, default_value Value) Value {
	value := (*mapping)[key] or { return default_value }
	return box(value)
}

// is_none tests the None singleton without invoking a value's equality method.
pub fn is_none(value Value) bool {
	return value is NoneType
}
