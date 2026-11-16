module collections

import pyrt

fn test_counter_operator_routes() { check_counter_operator_routes() or { panic(err.msg()) } }
fn check_counter_operator_routes() ! {
    a := counter(pyrt.Value('aab'))!
    b := counter(pyrt.Value('aaabb'))!
    zeros := counter(pyrt.Value('aab'))!
    zeros.set_item(pyrt.Value('z'), pyrt.Value(0))!
    // python: 'a' in collections.Counter('aab')
    assert a.contains(pyrt.Value('a'))!
    // python: bool(collections.Counter('aab'))
    assert a.bool_()
    // python: not bool(collections.Counter())
    assert !counter(pyrt.none_)!.bool_()
    // python: collections.Counter('aab') == collections.Counter(a=2,b=1,z=0)
    assert a.eq(zeros)!
    // python: collections.Counter('aab') <= collections.Counter('aaabb')
    assert a.le(b)!
    // python: collections.Counter('aab') < collections.Counter('aaabb')
    assert a.lt(b)!
    // python: collections.Counter('aaabb') >= collections.Counter('aab')
    assert b.ge(a)!
    // python: collections.Counter('aaabb') > collections.Counter('aab')
    assert b.gt(a)!
    // python: str(collections.Counter('abbbcc')) == "Counter({'b': 3, 'c': 2, 'a': 1})"
    assert counter(pyrt.Value('abbbcc'))!.str() == "Counter({'b': 3, 'c': 2, 'a': 1})"
    // python: str(collections.Counter()) == 'Counter()'
    assert counter(pyrt.none_)!.str() == 'Counter()'
}
