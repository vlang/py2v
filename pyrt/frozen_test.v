module pyrt

fn test_frozenset_hash_keys_and_repr() {
    a := frozenset_of([Value(i64(1)), Value('a')]) or { panic(err.msg()) }
    b := frozenset_of([Value('a'), Value(i64(1))]) or { panic(err.msg()) }
    // python: frozenset([1,'a']) == frozenset(['a',1])
    assert eq(a, b)
    // python: hash(frozenset([1,'a'])) == hash(frozenset(['a',1]))
    assert hash_key(a) or { '' } == hash_key(b) or { '' }
    // python: str(frozenset()) == 'frozenset()'
    assert str(frozenset_of([]Value{}) or { panic(err.msg()) }) == 'frozenset()'
    // python: isinstance(frozenset([1]), frozenset)
    assert type_name(a) == 'frozenset'
    d := new_dict()
    setitem(Value(d), a, Value('ok')) or { panic(err.msg()) }
    // python: {frozenset([1,'a']): 'ok'}[frozenset(['a',1])] == 'ok'
    assert str(getitem(Value(d), b) or { panic(err.msg()) }) == 'ok'
}

fn test_frozenset_operators_and_mutation() {
    a := frozenset_of([Value(i64(1)), Value(i64(2))]) or { panic(err.msg()) }
    b := frozenset_of([Value(i64(2)), Value(i64(3))]) or { panic(err.msg()) }
    both := frozen_union(a, b) or { panic(err.msg()) }
    // python: len(frozenset([1,2]) | frozenset([2,3])) == 3
    assert len_(both) or { -1 } == 3
    // python: 3 in (frozenset([1,2]) | frozenset([2,3]))
    assert contains(both, Value(i64(3))) or { false }
    common := frozen_intersection(a, b) or { panic(err.msg()) }
    // python: frozenset([1,2]) & frozenset([2,3]) == frozenset([2])
    assert eq(common, frozenset_of([Value(i64(2))]) or { panic(err.msg()) })
    if a is &Set {
        mut error_text := ''
        a.add(Value(i64(9))) or { error_text = err.msg() }
        // python: not hasattr(frozenset([1]), 'add')
        assert error_text.contains('add')
    }
}

fn test_frozenset_symmetric_difference_and_ordering() {
    a := frozenset_of([Value(i64(1)), Value(i64(2))]) or { panic(err.msg()) }
    b := frozenset_of([Value(i64(2)), Value(i64(3))]) or { panic(err.msg()) }
    unique := frozen_symmetric_difference(a, b) or { panic(err.msg()) }
    // python: frozenset([1,2]) ^ frozenset([2,3]) == frozenset([1,3])
    assert eq(unique, frozenset_of([Value(i64(1)), Value(i64(3))]) or { panic(err.msg()) })
    small := frozenset_of([Value(i64(1))]) or { panic(err.msg()) }
    // python: frozenset([1]) < frozenset([1,2])
    assert frozen_lt(small, a) or { false }
    // python: frozenset([1,2]) >= frozenset([1])
    assert frozen_ge(a, small) or { false }
    // python: frozenset([1,2]) <= frozenset([1,2])
    assert frozen_le(a, a) or { false }
}
