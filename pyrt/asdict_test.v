module pyrt

fn test_dataclass_asdict_instance_and_object() {
    mut obj := new_object('Point')
    obj.fields['x'] = Value(i64(2))
    obj.fields['y'] = Value(i64(5))
    v := dataclass_asdict(Value(Instance(obj)), ['x', 'y']) or { panic(err.msg()) }
    // python: __import__('dataclasses').asdict(__import__('dataclasses').make_dataclass('Point',['x','y'])(2,5)) == {'x':2,'y':5}
    assert as_int(getitem(v, Value('x')) or { panic(err.msg()) }) or { -1 } == 2
    // python: __import__('dataclasses').asdict(__import__('dataclasses').make_dataclass('Point',['x','y'])(2,5))['y'] == 5
    assert as_int(getitem(v, Value('y')) or { panic(err.msg()) }) or { -1 } == 5
}
