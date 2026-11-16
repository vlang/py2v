module collections

import pyrt

fn factory_seventeen() pyrt.Value { return pyrt.Value(i64(17)) }

fn test_defaultdict_factory_and_key_semantics() {
    d := defaultdict('list') or { panic(err.msg()) }
    // python: list(__import__('collections').defaultdict(list)['missing']) == []
    first := d.get_item(pyrt.Value('missing')) or { panic(err.msg()) }
    assert pyrt.repr(first) == '[]'
    // python: (lambda d: (d['a'].append(4),d['a'])[1])(__import__('collections').defaultdict(list)) == [4]
    pyrt.call_method(first, 'append', [pyrt.Value(i64(4))]) or { panic(err.msg()) }
    same := d.get_item(pyrt.Value('missing')) or { panic(err.msg()) }
    assert pyrt.repr(same) == '[4]'
    // python: (lambda d: (d['x'],len(d))[1])(__import__('collections').defaultdict(list)) == 1
    assert d.len() == 1
    // python: __import__('collections').defaultdict(int).get('a',7) == 7
    assert pyrt.repr(d.get(pyrt.Value('not_created'), pyrt.Value(i64(7))) or { panic(err.msg()) }) == '7'
    assert d.len() == 1
    // python: __import__('collections').defaultdict(int)['unknown'] == 0
    ints := defaultdict('int') or { panic(err.msg()) }
    assert pyrt.repr(ints.get_item(pyrt.Value('unknown')) or { panic(err.msg()) }) == '0'
    // python: __import__('collections').defaultdict(list).default_factory is list
    assert pyrt.str(d.getattr('default_factory') or { panic(err.msg()) }) == 'list'
    // runtime: custom V factory callback is accepted and invoked on missing keys.
    callback := defaultdict_fn(factory_seventeen)
    assert pyrt.repr(callback.get_item(pyrt.Value('x')) or { panic(err.msg()) }) == '17'
    // python: __import__('collections').defaultdict(None).default_factory is None
    empty_factory := defaultdict('') or { panic(err.msg()) }
    no_factory := empty_factory.getattr('default_factory') or { panic(err.msg()) }
    assert no_factory is pyrt.NoneType
    // python: error_text(lambda: __import__('collections').defaultdict(None)['bad']) == "KeyError|'bad'"
    _ = empty_factory.get_item(pyrt.Value('bad')) or { assert pyrt.caught(err, 'KeyError') != none; pyrt.none_ }
    // runtime: boxed instance identity and class name are maintained.
    assert pyrt.type_name(d.as_value()) == 'defaultdict'
}

fn test_counter_counting_most_common_and_subtract() {
    c := counter(pyrt.Value('ababa')) or { panic(err.msg()) }
    // python: __import__('collections').Counter('ababa')['a'] == 3
    assert pyrt.repr(c.get_item(pyrt.Value('a')) or { panic(err.msg()) }) == '3'
    // python: __import__('collections').Counter('ababa')['missing'] == 0
    assert pyrt.repr(c.get_item(pyrt.Value('missing')) or { panic(err.msg()) }) == '0'
    // python: __import__('collections').Counter('ababa').most_common(2) == [('a',3),('b',2)]
    first := c.most_common(2) or { panic(err.msg()) }
    assert pyrt.repr(pyrt.Value(pyrt.new_list(first))) == "[('a', 3), ('b', 2)]"
    // python: list(__import__('collections').Counter('aba').elements()) == ['a','a','b']
    abc := counter(pyrt.Value('aba')) or { panic(err.msg()) }
    assert pyrt.repr(pyrt.Value(pyrt.new_list(abc.elements() or { panic(err.msg()) }))) == "['a', 'a', 'b']"
    // python: __import__('collections').Counter('ababa').total() == 5
    assert pyrt.repr(c.total() or { panic(err.msg()) }) == '5'
    // python: (lambda c: (c.subtract('aaa'),c['a'],c['b'])[1:])(__import__('collections').Counter('ababa')) == (0,2)
    c.subtract(pyrt.Value('aaa')) or { panic(err.msg()) }
    assert pyrt.repr(c.get_item(pyrt.Value('a')) or { panic(err.msg()) }) == '0'
    assert pyrt.repr(c.get_item(pyrt.Value('b')) or { panic(err.msg()) }) == '2'
    // python: __import__('collections').Counter('ab').most_common(0) == []
    assert (c.most_common(0) or { panic(err.msg()) }).len == 0
    // python: __import__('collections').Counter('ab').most_common(-1) == []
    assert (c.most_common(-1) or { panic(err.msg()) }).len == 0
    // python: len(__import__('collections').Counter({'a':0,'b':-2})) == 2
    assert c.len() == 2
    // runtime: boxed Counter supports Instance identity/type, not mapping protocol.
    assert pyrt.type_name(c.as_value()) == 'Counter'
}

fn test_counter_mapping_update_and_arithmetic() {
    mapping := pyrt.new_dict()
    pyrt.setitem(pyrt.Value(mapping), pyrt.Value('a'), pyrt.Value(i64(3))) or { panic(err.msg()) }
    pyrt.setitem(pyrt.Value(mapping), pyrt.Value('b'), pyrt.Value(i64(1))) or { panic(err.msg()) }
    c := counter(pyrt.Value(mapping)) or { panic(err.msg()) }
    // python: __import__('collections').Counter({'a':3,'b':1})['a'] == 3
    assert pyrt.repr(c.get_item(pyrt.Value('a')) or { panic(err.msg()) }) == '3'
    other := counter(pyrt.Value('abb')) or { panic(err.msg()) }
    both := c.add_counter(other) or { panic(err.msg()) }
    // python: dict(__import__('collections').Counter({'a':3,'b':1}) + __import__('collections').Counter('abb')) == {'a':4,'b':3}
    assert pyrt.repr(pyrt.Value(both.as_dict())) == "{'a': 4, 'b': 3}"
    diff := c.sub_counter(other) or { panic(err.msg()) }
    // python: dict(__import__('collections').Counter({'a':3,'b':1}) - __import__('collections').Counter('abb')) == {'a':2}
    assert pyrt.repr(pyrt.Value(diff.as_dict())) == "{'a': 2}"
    // python: list(__import__('collections').OrderedDict([('x',1),('y',2)])) == ['x','y']
    ordered := ordered_dict([Entry{key: pyrt.Value('x'), value: pyrt.Value(i64(1))},
        Entry{key: pyrt.Value('y'), value: pyrt.Value(i64(2))}]) or { panic(err.msg()) }
    assert pyrt.repr(pyrt.Value(ordered)) == "{'x': 1, 'y': 2}"
}

fn test_deque_indexing_mutation_and_iteration() {
    mut d := deque([pyrt.Value(i64(1)), pyrt.Value(i64(2))], DequeOptions{}) or { panic(err.msg()) }
    // python: list(__import__('collections').deque([1,2])) == [1,2]
    assert pyrt.repr(d.as_value()) == '[1, 2]'
    d.appendleft(pyrt.Value(i64(0)))
    // python: list(__import__('collections').deque([0,1,2])) == [0,1,2]
    assert pyrt.repr(d.as_value()) == '[0, 1, 2]'
    // python: __import__('collections').deque([0,1,2])[-1] == 2
    assert pyrt.repr(pyrt.getitem(d.as_value(), pyrt.Value(i64(-1))) or { panic(err.msg()) }) == '2'
    // python: (lambda d: (d.popleft(), list(d)))(__import__('collections').deque([0,1,2])) == (0,[1,2])
    assert pyrt.repr(d.popleft() or { panic(err.msg()) }) == '0'
    assert pyrt.repr(d.as_value()) == '[1, 2]'
    d.rotate(1)
    // python: (lambda d: (d.rotate(1), list(d))[1])(__import__('collections').deque([1,2])) == [2,1]
    assert pyrt.repr(d.as_value()) == '[2, 1]'
    d.set(0, pyrt.Value(i64(9))) or { panic(err.msg()) }
    // python: (lambda d: (d.__setitem__(0,9),list(d))[1])(__import__('collections').deque([2,1])) == [9,1]
    assert pyrt.repr(d.as_value()) == '[9, 1]'
    // python: len(__import__('collections').deque([9,1])) == 2
    assert d.len() == 2
    d.delete(0) or { panic(err.msg()) }
    // python: (lambda d: (d.__delitem__(0),list(d))[1])(__import__('collections').deque([9,1])) == [1]
    assert pyrt.repr(d.as_value()) == '[1]'
    // python: error_text(lambda: __import__('collections').deque().pop()) == 'IndexError|pop from an empty deque'
    empty := deque([]pyrt.Value{}, DequeOptions{}) or { panic(err.msg()) }
    mut e := empty
    _ = e.pop() or { assert pyrt.caught(err, 'IndexError') != none; pyrt.none_ }
}

fn test_deque_maxlen_and_extendleft() {
    mut d := deque([pyrt.Value(i64(1)), pyrt.Value(i64(2))], DequeOptions{maxlen: 2}) or { panic(err.msg()) }
    d.append(pyrt.Value(i64(3)))
    // python: (lambda d: (d.append(3),list(d))[1])(__import__('collections').deque([1,2],maxlen=2)) == [2,3]
    assert pyrt.repr(d.as_value()) == '[2, 3]'
    d.appendleft(pyrt.Value(i64(9)))
    // python: (lambda d: (d.appendleft(9),list(d))[1])(__import__('collections').deque([2,3],maxlen=2)) == [9,2]
    assert pyrt.repr(d.as_value()) == '[9, 2]'
    d.extendleft([pyrt.Value(i64(7)), pyrt.Value(i64(8))])
    // python: (lambda d: (d.extendleft([7,8]),list(d))[1])(__import__('collections').deque([9,2],maxlen=2)) == [8,7]
    assert pyrt.repr(d.as_value()) == '[8, 7]'
    // python: __import__('collections').deque([1,2,3],maxlen=0).__len__() == 0
    zero := deque([pyrt.Value(i64(1))], DequeOptions{maxlen: 0}) or { panic(err.msg()) }
    assert zero.len() == 0
    // python: error_text(lambda: __import__('collections').deque(maxlen=-1)) == 'ValueError|maxlen must be non-negative'
    _ = deque([]pyrt.Value{}, DequeOptions{maxlen: -1}) or {
        assert pyrt.caught(err, 'ValueError') != none
        &Deque{}
    }
}

fn test_defaultdict_mutating_dictionary_methods() {
    d := defaultdict('int') or { panic(err.msg()) }
    d.set_item(pyrt.Value('x'), pyrt.Value(i64(8))) or { panic(err.msg()) }
    // python: (lambda d: (d.__setitem__('x',8),d['x'])[1])(__import__('collections').defaultdict(int)) == 8
    assert pyrt.repr(d.get_item(pyrt.Value('x')) or { panic(err.msg()) }) == '8'
    // python: list(__import__('collections').defaultdict(int,{'x':8}).items()) == [('x',8)]
    assert pyrt.repr(pyrt.Value(pyrt.new_list(d.items() or { panic(err.msg()) }))) == "[('x', 8)]"
    d.del_item(pyrt.Value('x')) or { panic(err.msg()) }
    // python: (lambda d: (d.__delitem__('x'),len(d))[1])(__import__('collections').defaultdict(int,{'x':8})) == 0
    assert d.len() == 0
    d.set_item(pyrt.Value('y'), pyrt.Value(i64(1))) or { panic(err.msg()) }
    d.clear()
    // python: (lambda d: (d.clear(),len(d))[1])(__import__('collections').defaultdict(int,{'y':1})) == 0
    assert d.len() == 0
}

fn test_counter_copy_delete_update_and_deque_copy() {
    source := pyrt.Value(pyrt.new_list([pyrt.Value('x'), pyrt.Value('x')]))
    c := counter(source) or { panic(err.msg()) }
    c.increment(pyrt.Value('z'), pyrt.Value(i64(4))) or { panic(err.msg()) }
    // python: (lambda c: (c.update({'z':4}),c['z'])[1])(__import__('collections').Counter('xx')) == 4
    assert pyrt.repr(c.get_item(pyrt.Value('z')) or { panic(err.msg()) }) == '4'
    cloned := c.copy() or { panic(err.msg()) }
    cloned.del_item(pyrt.Value('z')) or { panic(err.msg()) }
    // python: (lambda c: (c.__delitem__('z'),c['z'])[1])(__import__('collections').Counter({'z':4})) == 0
    assert pyrt.repr(cloned.get_item(pyrt.Value('z')) or { panic(err.msg()) }) == '0'
    // python: __import__('collections').Counter('xx')['x'] == 2
    assert pyrt.repr(c.get_item(pyrt.Value('x')) or { panic(err.msg()) }) == '2'
    cloned.update_counter(c) or { panic(err.msg()) }
    // runtime: the original and copied Counter do not share the mapping itself.
    assert pyrt.repr(cloned.get_item(pyrt.Value('z')) or { panic(err.msg()) }) == '4'
    cloned.clear()
    // python: (lambda c: (c.clear(),len(c))[1])(__import__('collections').Counter('xx')) == 0
    assert cloned.len() == 0

    mut d := deque([pyrt.Value(i64(1))], DequeOptions{}) or { panic(err.msg()) }
    d.extend([pyrt.Value(i64(2)), pyrt.Value(i64(1))])
    // python: (lambda d: (d.extend([2,1]),list(d))[1])(__import__('collections').deque([1])) == [1,2,1]
    assert pyrt.repr(d.as_value()) == '[1, 2, 1]'
    // python: __import__('collections').deque([1,2,1]).count(1) == 2
    assert d.count(pyrt.Value(i64(1))) == 2
    mut copy := d.copy() or { panic(err.msg()) }
    // python: __import__('collections').deque([1,2,1]).pop() == 1
    assert pyrt.repr(copy.pop() or { panic(err.msg()) }) == '1'
    // python: list(__import__('collections').deque([1,2,1])) == [1,2,1]
    assert pyrt.repr(d.as_value()) == '[1, 2, 1]'
    copy.clear()
    // python: (lambda d: (d.clear(),len(d))[1])(__import__('collections').deque([1,2,1])) == 0
    assert copy.len() == 0
}
