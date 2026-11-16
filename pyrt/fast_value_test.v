module pyrt

fn test_round8_direct_value_accessors() {
    d := new_dict()
    setitem(Value(d), Value('first'), Value(i64(1))) or { panic(err.msg()) }
    setitem(Value(d), Value('second'), Value('two')) or { panic(err.msg()) }
    // python: {'first':1,'second':'two'}.get('absent',3) == 3
    assert repr(get(Value(d), Value('absent'), Value(i64(3)))) == '3'
    // python: {'first':1,'second':'two'}.get('first',3) == 1
    assert repr(get(Value(d), Value('first'), Value(i64(3)))) == '1'
    bool_keys := new_dict()
    setitem(Value(bool_keys), Value(true), Value('yes')) or { panic(err.msg()) }
    // python: {True:'yes'}.get(1) == 'yes'
    assert repr(get(Value(bool_keys), Value(i64(1)), none_)) == "'yes'"
    // python: {True:'yes'}.get(1.0) == 'yes'
    assert repr(get(Value(bool_keys), Value(1.0), none_)) == "'yes'"
    // python: list({'first':1,'second':'two'}.keys()) == ['first','second']
    assert repr(keys(Value(d)) or { panic(err.msg()) }) == "['first', 'second']"
    // python: list({'first':1,'second':'two'}.items()) == [('first',1),('second','two')]
    assert repr(items(Value(d)) or { panic(err.msg()) }) == "[('first', 1), ('second', 'two')]"
    // python: list({'first':1,'second':'two'}.values()) == [1,'two']
    assert repr(values(Value(d)) or { panic(err.msg()) }) == "[1, 'two']"
    // python: len({'first':1,'second':'two'}) == 2
    direct_dict := as_dict(Value(d)) or { panic(err.msg()) }
    assert direct_dict.keys.len == 2
    // python: isinstance(1, dict) is False
    _ = as_dict(Value(i64(1))) or {
        assert caught(err, 'TypeError') != none
        d
    }
    // python: isinstance('hi', str)
    assert (as_str(Value('hi')) or { '' }) == 'hi'
}

fn test_round8_direct_string_methods() {
    // python: ' X '.strip() == 'X'
    assert str(strip(Value(' X ')) or { panic(err.msg()) }) == 'X'
    // python: 'xxAx'.strip('x') == 'A'
    assert str(strip_chars(Value('xxAx'), Value('x')) or { panic(err.msg()) }) == 'A'
    // python: 'Straße'.upper() == 'STRASSE'
    assert str(upper(Value('Straße')) or { panic(err.msg()) }) == 'STRASSE'
    // python: 'ABC'.lower() == 'abc'
    assert str(lower(Value('ABC')) or { panic(err.msg()) }) == 'abc'
    // python: ' a  b '.split() == ['a', 'b']
    assert repr(split(Value(' a  b ')) or { panic(err.msg()) }) == "['a', 'b']"
    // python: 'a:b:c'.split(':',1) == ['a','b:c']
    assert repr(split_n(Value('a:b:c'), Value(':'), 1) or { panic(err.msg()) }) == "['a', 'b:c']"
    // python: 'abcabc'.replace('ab','x',1) == 'xcabc'
    assert str(replace_n(Value('abcabc'), Value('ab'), Value('x'), 1) or { panic(err.msg()) }) == 'xcabc'
    // python: 'abc'.replace('b','x') == 'axc'
    assert str(replace(Value('abc'), Value('b'), Value('x')) or { panic(err.msg()) }) == 'axc'
    // python: 'hello'.startswith(('xx','he'))
    assert (startswith(Value('hello'), tuple_of(Value('xx'), Value('he'))) or { false })
    // python: 'hello'.endswith('lo')
    assert (endswith(Value('hello'), Value('lo')) or { false })
    // python: ','.join(['a','b']) == 'a,b'
    assert str(join(Value(','), Value(new_list([Value('a'), Value('b')]))) or { panic(err.msg()) }) == 'a,b'
    // python: isinstance(1, str) is False
    _ = lower(Value(i64(1))) or { assert caught(err, 'TypeError') != none; none_ }
}

fn test_round8_tuples_and_unpacking() {
    pair := tuple_of(Value('name'), Value(0.5))
    // python: ('name',0.5) == ('name',0.5)
    assert repr(pair) == "('name', 0.5)"
    // python: ('name',0.5)[-1] == 0.5
    assert repr(tuple_item(pair, -1) or { panic(err.msg()) }) == '0.5'
    // python: list(('name',0.5)) == ['name',0.5]
    tuple_parts := tuple_items(pair) or { panic(err.msg()) }
    assert tuple_parts.len == 2
    // python: len(('name',0.5)) == 2
    pair_parts := unpack(pair, 2) or { panic(err.msg()) }
    assert pair_parts.len == 2
    // python: 'too many values to unpack' in str(__import__('builtins').ValueError('too many values to unpack (expected 1)'))
    _ = unpack(pair, 1) or { assert err.msg() == 'too many values to unpack (expected 1)'; []Value{} }
    // python: 'not enough values to unpack' in str(__import__('builtins').ValueError('not enough values to unpack (expected 3, got 2)'))
    _ = unpack(pair, 3) or { assert err.msg() == 'not enough values to unpack (expected 3, got 2)'; []Value{} }
}

fn round8_never() Value {
    panic('right-hand side was evaluated eagerly')
}

fn round8_rhs() Value { return Value('called') }

fn test_round8_lazy_boolean_operators() {
    // python: ('left' or (_ for _ in ()).throw(AssertionError('eager'))) == 'left'
    assert str(either_lazy(Value('left'), round8_never)) == 'left'
    // python: (0 and (_ for _ in ()).throw(AssertionError('eager'))) == 0
    assert repr(both_lazy(Value(i64(0)), round8_never)) == '0'
    // python: ('' or 'called') == 'called'
    assert str(either_lazy(Value(''), round8_rhs)) == 'called'
    // python: ('left' and 'called') == 'called'
    assert str(both_lazy(Value('left'), round8_rhs)) == 'called'
}
