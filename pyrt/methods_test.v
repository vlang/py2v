module pyrt

fn invoke_method(v Value, name string, args ...Value) Value {
    return call_method(v, name, args) or { panic(err.msg()) }
}

fn test_method_string_casing_and_properties() {
    // python: 'Abc ö'.upper() == 'ABC Ö'
    assert str(invoke_method(Value('Abc ö'), 'upper')) == 'ABC Ö'
    // python: 'AbC Ö'.lower() == 'abc ö'
    assert str(invoke_method(Value('AbC Ö'), 'lower')) == 'abc ö'
    // python: 'straße'.upper() == 'STRASSE'
    assert str(invoke_method(Value('straße'), 'upper')) == 'STRASSE'
    // python: 'they\'re ok'.title() == 'They\'Re Ok'
    assert str(invoke_method(Value("they're ok"), 'title')) == "They'Re Ok"
    // python: 'HELLO WORLD'.capitalize() == 'Hello world'
    assert str(invoke_method(Value('HELLO WORLD'), 'capitalize')) == 'Hello world'
    // python: '٣'.isdigit() and 'α'.isalpha() and '中5'.isalnum()
    assert truth(invoke_method(Value('٣'), 'isdigit'))
    assert truth(invoke_method(Value('α'), 'isalpha'))
    assert truth(invoke_method(Value('中5'), 'isalnum'))
    // python: '\u00a0\n'.isspace()
    assert truth(invoke_method(Value('\u00a0\n'), 'isspace'))
    // python: 'ABC!'.isupper() and 'abc!'.islower()
    assert truth(invoke_method(Value('ABC!'), 'isupper'))
    assert truth(invoke_method(Value('abc!'), 'islower'))
    // python: not '123'.islower() and not ''.isalpha()
    assert !truth(invoke_method(Value('123'), 'islower'))
    assert !truth(invoke_method(Value(''), 'isalpha'))
}

fn test_method_string_splitting_and_search() {
    // python: '  α  β \t'.strip() == 'α  β'
    assert str(invoke_method(Value('  α  β \t'), 'strip')) == 'α  β'
    // python: 'xxHELLOxy'.lstrip('xy') == 'HELLOxy'
    assert str(invoke_method(Value('xxHELLOxy'), 'lstrip', Value('xy'))) == 'HELLOxy'
    // python: 'xxHELLOxy'.rstrip('xy') == 'xxHELLO'
    assert str(invoke_method(Value('xxHELLOxy'), 'rstrip', Value('xy'))) == 'xxHELLO'
    // python: ' a  b c '.split() == ['a','b','c']
    assert str(invoke_method(Value(' a  b c '), 'split')) == "['a', 'b', 'c']"
    // python: ' a  b c '.split(None, 1) == ['a','b c ']
    assert str(invoke_method(Value(' a  b c '), 'split', none_, Value(i64(1)))) == "['a', 'b c ']"
    // python: 'a:b:c'.split(':',1) == ['a','b:c']
    assert str(invoke_method(Value('a:b:c'), 'split', Value(':'), Value(i64(1)))) == "['a', 'b:c']"
    // python: 'a:b:c'.rsplit(':',1) == ['a:b','c']
    assert str(invoke_method(Value('a:b:c'), 'rsplit', Value(':'), Value(i64(1)))) == "['a:b', 'c']"
    // python: ','.join(['a','b','c']) == 'a,b,c'
    assert str(invoke_method(Value(','), 'join', Value(new_list([Value('a'), Value('b'), Value('c')])))) == 'a,b,c'
    // python: 'abcabc'.replace('ab','X',1) == 'Xcabc'
    assert str(invoke_method(Value('abcabc'), 'replace', Value('ab'), Value('X'), Value(i64(1)))) == 'Xcabc'
    // python: 'abc'.replace('','-',2) == '-a-bc'
    assert str(invoke_method(Value('abc'), 'replace', Value(''), Value('-'), Value(i64(2)))) == '-a-bc'
    // python: 'éabc'.find('a') == 1
    assert str(invoke_method(Value('éabc'), 'find', Value('a'))) == '1'
    // python: 'ababa'.rfind('ba') == 3
    assert str(invoke_method(Value('ababa'), 'rfind', Value('ba'))) == '3'
    // python: 'ababa'.count('aba') == 1
    assert str(invoke_method(Value('ababa'), 'count', Value('aba'))) == '1'
    // python: 'abc'.count('') == 4
    assert str(invoke_method(Value('abc'), 'count', Value(''))) == '4'
    // python: 'hello'.startswith(('xx','he')) and 'hello'.endswith('lo')
    assert truth(invoke_method(Value('hello'), 'startswith', Value(new_tuple([Value('xx'), Value('he')]))))
    assert truth(invoke_method(Value('hello'), 'endswith', Value('lo')))
    // python: 'x\r\ny\nz'.splitlines(True) == ['x\r\n','y\n','z']
    assert str(invoke_method(Value('x\r\ny\nz'), 'splitlines', Value(true))) == "['x\\r\\n', 'y\\n', 'z']"
    // python: 'a:b:c'.partition(':') == ('a',':','b:c')
    assert str(invoke_method(Value('a:b:c'), 'partition', Value(':'))) == "('a', ':', 'b:c')"
}

fn test_method_string_format_padding_encoding() {
    // python: 'x{}y{}'.format(1,2) == 'x1y2'
    assert str(invoke_method(Value('x{}y{}'), 'format', Value(i64(1)), Value(i64(2)))) == 'x1y2'
    // python: '{{{0!r}}}'.format('x') == "{'x'}"
    assert str(invoke_method(Value('{{{0!r}}}'), 'format', Value('x'))) == "{'x'}"
    // python: '-42'.zfill(6) == '-00042'
    assert str(invoke_method(Value('-42'), 'zfill', Value(i64(6)))) == '-00042'
    // python: 'ab'.ljust(5,'.') == 'ab...'
    assert str(invoke_method(Value('ab'), 'ljust', Value(i64(5)), Value('.'))) == 'ab...'
    // python: 'ab'.rjust(5,'.') == '...ab'
    assert str(invoke_method(Value('ab'), 'rjust', Value(i64(5)), Value('.'))) == '...ab'
    // python: 'ab'.center(5,'.') == '..ab.'
    assert str(invoke_method(Value('ab'), 'center', Value(i64(5)), Value('.'))) == '..ab.'
    // python: 'é'.encode('utf-8') == b'\xc3\xa9'
    assert repr(invoke_method(Value('é'), 'encode')) == "b'\\xc3\\xa9'"
    // python: 'é'.encode('latin-1') == b'\xe9'
    assert repr(invoke_method(Value('é'), 'encode', Value('latin-1'))) == "b'\\xe9'"
    // python: b'\xc3\xa9'.decode('utf-8') == 'é'
    assert str(invoke_method(Value([u8(0xc3), 0xa9]), 'decode')) == 'é'
    // python: b'\x00\xff'.hex() == '00ff'
    assert str(invoke_method(Value([u8(0), 0xff]), 'hex')) == '00ff'
    // python: b'\x00\xff'.hex(':') == '00:ff'
    assert str(invoke_method(Value([u8(0), 0xff]), 'hex', Value(':'))) == '00:ff'
}

fn test_method_list_mutation() {
    list := new_list([Value(i64(1)), Value(i64(2))])
    // python: exec_result('a=[1,2];a.append(3)','a') == [1,2,3]
    _ = invoke_method(Value(list), 'append', Value(i64(3)))
    assert str(Value(list)) == '[1, 2, 3]'
    // python: exec_result('a=[1,2,3];a.extend([4,5])','a') == [1,2,3,4,5]
    _ = invoke_method(Value(list), 'extend', Value(new_list([Value(i64(4)), Value(i64(5))])))
    assert str(Value(list)) == '[1, 2, 3, 4, 5]'
    // python: exec_result('a=[1,2,3,4,5];a.insert(-1,99)','a') == [1,2,3,4,99,5]
    _ = invoke_method(Value(list), 'insert', Value(i64(-1)), Value(i64(99)))
    assert str(Value(list)) == '[1, 2, 3, 4, 99, 5]'
    // python: exec_result('a=[1,2,3,4,99,5];n=a.pop(-2)','n') == 99
    assert str(invoke_method(Value(list), 'pop', Value(i64(-2)))) == '99'
    // python: exec_result('a=[1,2,3,4,5];a.remove(2)','a') == [1,3,4,5]
    _ = invoke_method(Value(list), 'remove', Value(i64(2)))
    assert str(Value(list)) == '[1, 3, 4, 5]'
    // python: [1,3,4,5].index(4) == 2
    assert str(invoke_method(Value(list), 'index', Value(i64(4)))) == '2'
    // python: [1,3,4,5].count(1) == 1
    assert str(invoke_method(Value(list), 'count', Value(i64(1)))) == '1'
    // python: exec_result('a=[1,3,4,5];a.reverse()','a') == [5,4,3,1]
    _ = invoke_method(Value(list), 'reverse')
    assert str(Value(list)) == '[5, 4, 3, 1]'
    // python: exec_result('a=[5,4,3,1];a.sort()','a') == [1,3,4,5]
    _ = invoke_method(Value(list), 'sort')
    assert str(Value(list)) == '[1, 3, 4, 5]'
    // python: [1,3,4,5].copy() == [1,3,4,5]
    assert str(invoke_method(Value(list), 'copy')) == '[1, 3, 4, 5]'
    // python: exec_result('a=[1,3,4,5];a.clear()','a') == []
    _ = invoke_method(Value(list), 'clear')
    assert str(Value(list)) == '[]'
}

fn test_method_dict_set_tuple() {
    d := new_dict()
    setitem(Value(d), Value('a'), Value(i64(1))) or { panic(err.msg()) }
    // python: {'a':1}.get('missing',3) == 3
    assert str(invoke_method(Value(d), 'get', Value('missing'), Value(i64(3)))) == '3'
    // python: {'a':1}.setdefault('b',2) == 2
    assert str(invoke_method(Value(d), 'setdefault', Value('b'), Value(i64(2)))) == '2'
    // python: list({'a':1,'b':2}.keys()) == ['a','b']
    assert str(invoke_method(Value(d), 'keys')) == "['a', 'b']"
    // python: list({'a':1,'b':2}.values()) == [1,2]
    assert str(invoke_method(Value(d), 'values')) == '[1, 2]'
    // python: list({'a':1,'b':2}.items()) == [('a',1),('b',2)]
    assert str(invoke_method(Value(d), 'items')) == "[('a', 1), ('b', 2)]"
    // python: {'a':1,'b':2}.pop('b') == 2
    assert str(invoke_method(Value(d), 'pop', Value('b'))) == '2'
    // python: {'a':1}.copy() == {'a':1}
    assert str(invoke_method(Value(d), 'copy')) == "{'a': 1}"
    update_pairs := new_list([Value(new_tuple([Value('z'), Value(i64(5))]))])
    // python: exec_result("d={'a':1};d.update([('z',5)])",'d') == {'a':1,'z':5}
    _ = invoke_method(Value(d), 'update', Value(update_pairs))
    assert str(Value(d)) == "{'a': 1, 'z': 5}"
    // python: exec_result("d={'a':1,'z':5};d.clear()",'d') == {}
    _ = invoke_method(Value(d), 'clear')
    assert str(Value(d)) == '{}'

    set := new_set([Value(i64(1)), Value(i64(2))]) or { panic(err.msg()) }
    // python: exec_result('s={1,2};s.add(3)','s') == {1,2,3}
    _ = invoke_method(Value(set), 'add', Value(i64(3)))
    assert truth(invoke_method(Value(set), 'issuperset', Value(new_list([Value(i64(2)), Value(i64(3))]))))
    // python: {1,2,3}.issubset({1,2,3,4})
    assert truth(invoke_method(Value(set), 'issubset', Value(new_set([Value(i64(1)),Value(i64(2)),Value(i64(3)),Value(i64(4))]) or { panic(err.msg()) })))
    // python: exec_result('s={1,2,3};s.discard(1)','s') == {2,3}
    _ = invoke_method(Value(set), 'discard', Value(i64(1)))
    // python: {2,3}.union({4}) == {2,3,4}
    unioned := invoke_method(Value(set), 'union', Value(new_set([Value(i64(4))]) or { panic(err.msg()) }))
    assert (contains(unioned, Value(i64(4))) or { false })
    // python: {2,3}.intersection({3,4}) == {3}
    intersected := invoke_method(Value(set), 'intersection', Value(new_list([Value(i64(3)),Value(i64(4))])))
    assert str(intersected) == '{3}'
    // python: {2,3}.difference({3}) == {2}
    difference := invoke_method(Value(set), 'difference', Value(new_list([Value(i64(3))])))
    assert str(difference) == '{2}'
    // python: exec_result('s={2,3};s.update([4])','s') == {2,3,4}
    _ = invoke_method(Value(set), 'update', Value(new_list([Value(i64(4))])))
    assert truth(invoke_method(Value(set), 'issuperset', Value(new_list([Value(i64(4))]))))
    // python: {2,3,4}.copy() == {2,3,4}
    assert str(invoke_method(Value(set), 'copy')) == '{2, 3, 4}'
    // python: exec_result('s={2,3,4};s.clear()','s') == set()
    _ = invoke_method(Value(set), 'clear')
    assert str(Value(set)) == 'set()'
    tuple := new_tuple([Value('a'),Value(i64(2)),Value('a')])
    // python: ('a',2,'a').index('a',1) == 2
    assert str(invoke_method(Value(tuple), 'index', Value('a'), Value(i64(1)))) == '2'
    // python: ('a',2,'a').count('a') == 2
    assert str(invoke_method(Value(tuple), 'count', Value('a'))) == '2'
}

fn test_method_errors_and_non_result_wrapper() {
    // python: error_text(lambda: ''.index('a')) == 'ValueError|substring not found'
    _ = call_method(Value(''), 'index', [Value('a')]) or { assert err.msg() == 'substring not found'; none_ }
    // python: error_text(lambda: 'abc'.split('')) == 'ValueError|empty separator'
    _ = call_method(Value('abc'), 'split', [Value('')]) or { assert err.msg() == 'empty separator'; none_ }
    // python: error_text(lambda: [].pop()) == 'IndexError|pop from empty list'
    _ = call_method(Value(new_list([]Value{})), 'pop', []Value{}) or { assert err.msg() == 'pop from empty list'; none_ }
    // python: error_text(lambda: [1].remove(2)) == 'ValueError|list.remove(x): x not in list'
    _ = call_method(Value(new_list([Value(i64(1))])), 'remove', [Value(i64(2))]) or { assert err.msg() == 'list.remove(x): x not in list'; none_ }
    // python: error_text(lambda: ('a',).index('x')) == 'ValueError|tuple.index(x): x not in tuple'
    _ = call_method(Value(new_tuple([Value('a')])), 'index', [Value('x')]) or { assert err.msg() == 'tuple.index(x): x not in tuple'; none_ }
    // runtime: the non-result wrapper is successful for a supported call.
    assert str(method(Value('a'), 'upper', []Value{})) == 'A'
}
