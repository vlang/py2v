module pyrt

fn test_map_get_preserves_values_and_returns_none_for_absent_keys() {
	values := {
		'zero':  Value(0)
		'empty': Value('')
		'none':  none_
	}
	assert repr(map_get(values, 'zero', none_)) == '0'
	assert repr(map_get(values, 'empty', none_)) == "''"
	assert is_none(map_get(values, 'none', Value('fallback')))
	assert is_none(map_get(values, 'absent', none_))
	assert repr(map_get(values, 'absent', Value('fallback'))) == "'fallback'"
}

fn map_get_test_default(mut values map[string]Value) Value {
	values['present'] = Value('changed')
	values['new'] = Value('inserted')
	return Value('fallback')
}

fn test_map_get_observes_mutations_during_default_evaluation() {
	mut values := {
		'present': Value('old')
	}
	assert repr(map_get(&values, 'present', map_get_test_default(mut values))) == "'changed'"
	assert repr(map_get(&values, 'new', map_get_test_default(mut values))) == "'inserted'"
}

fn test_none_identity_excludes_false_values() {
	assert is_none(none_)
	assert !is_none(Value(0))
	assert !is_none(Value(''))
	assert !is_none(Value(false))
}
