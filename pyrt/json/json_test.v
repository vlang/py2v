module json

import os
import pyrt

fn test_loads_values() {
    check_loads_values() or { assert false, err.msg() }
}

fn check_loads_values() ! {
    // python: repr(__import__('json').loads('null')) == 'None'
    assert pyrt.repr(loads('null')!) == 'None'
    // python: repr(__import__('json').loads('true')) == 'True'
    assert pyrt.repr(loads('true')!) == 'True'
    // python: repr(__import__('json').loads('false')) == 'False'
    assert pyrt.repr(loads('false')!) == 'False'
    // python: repr(__import__('json').loads('123')) == '123'
    assert pyrt.repr(loads('123')!) == '123'
    // python: repr(__import__('json').loads('-42')) == '-42'
    assert pyrt.repr(loads('-42')!) == '-42'
    // python: repr(__import__('json').loads('-0')) == '0'
    assert pyrt.repr(loads('-0')!) == '0'
    // python: repr(__import__('json').loads('-0.0')) == '-0.0'
    assert pyrt.repr(loads('-0.0')!) == '-0.0'
    // python: repr(__import__('json').loads('0.5')) == '0.5'
    assert pyrt.repr(loads('0.5')!) == '0.5'
    // python: repr(__import__('json').loads('1e2')) == '100.0'
    assert pyrt.repr(loads('1e2')!) == '100.0'
    // python: repr(__import__('json').loads('[1,"a",false,null]')) == "[1, 'a', False, None]"
    assert pyrt.repr(loads('[1,"a",false,null]')!) == "[1, 'a', False, None]"
    // python: repr(__import__('json').loads('{"a":1,"b":[2]}')) == "{'a': 1, 'b': [2]}"
    assert pyrt.repr(loads('{"a":1,"b":[2]}')!) == "{'a': 1, 'b': [2]}"
    // python: repr(__import__('json').loads('{"a":1,"b":2,"a":3}')) == "{'a': 3, 'b': 2}"
    assert pyrt.repr(loads('{"a":1,"b":2,"a":3}')!) == "{'a': 3, 'b': 2}"
    // python: repr(__import__('json').loads('"a\\nb"')) == "'a\\nb'"
    assert pyrt.repr(loads('"a\\nb"')!) == "'a\\nb'"
    // python: repr(__import__('json').loads('"\\u0041"')) == "'A'"
    assert pyrt.repr(loads('"\\u0041"')!) == "'A'"
    // python: repr(__import__('json').loads('"\\u00e9"')) == "'é'"
    assert pyrt.repr(loads('"\\u00e9"')!) == "'é'"
    // python: repr(__import__('json').loads('"\\ud83d\\ude42"')) == "'🙂'"
    assert pyrt.repr(loads('"\\ud83d\\ude42"')!) == "'🙂'"
    // python: repr(__import__('json').loads('NaN')) == 'nan'
    assert pyrt.repr(loads('NaN')!) == 'nan'
    // python: repr(__import__('json').loads('Infinity')) == 'inf'
    assert pyrt.repr(loads('Infinity')!) == 'inf'
    // python: repr(__import__('json').loads('-Infinity')) == '-inf'
    assert pyrt.repr(loads('-Infinity')!) == '-inf'
}

fn test_loads_binary64_boundaries() {
    check_loads_binary64_boundaries() or { assert false, err.msg() }
}

fn check_loads_binary64_boundaries() ! {
    // Python's decimal-to-binary64 conversion rounds to nearest/even.
    // python: repr(__import__('json').loads('5e-324')) == '5e-324'
    assert pyrt.repr(loads('5e-324')!) == '5e-324'
    // python: repr(__import__('json').loads('4e-324')) == '5e-324'
    assert pyrt.repr(loads('4e-324')!) == '5e-324'
    // python: repr(__import__('json').loads('2.2250738585072014e-308')) == '2.2250738585072014e-308'
    assert pyrt.repr(loads('2.2250738585072014e-308')!) == '2.2250738585072014e-308'
    // python: repr(__import__('json').loads('2.225073858507201e-308')) == '2.225073858507201e-308'
    assert pyrt.repr(loads('2.225073858507201e-308')!) == '2.225073858507201e-308'
    // python: repr(__import__('json').loads('1.2345678901234567')) == '1.2345678901234567'
    assert pyrt.repr(loads('1.2345678901234567')!) == '1.2345678901234567'
    // python: repr(__import__('json').loads('9007199254740992.0')) == '9007199254740992.0'
    assert pyrt.repr(loads('9007199254740992.0')!) == '9007199254740992.0'
    // python: repr(__import__('json').loads('1e309')) == 'inf'
    assert pyrt.repr(loads('1e309')!) == 'inf'
    // python: repr(__import__('json').loads('1e-400')) == '0.0'
    assert pyrt.repr(loads('1e-400')!) == '0.0'
    // python: repr(__import__('json').loads('-1e-400')) == '-0.0'
    assert pyrt.repr(loads('-1e-400')!) == '-0.0'
    // python: repr(__import__('json').loads('1.7976931348623157e308')) == '1.7976931348623157e+308'
    assert pyrt.repr(loads('1.7976931348623157e308')!) == '1.7976931348623157e+308'
    // python: repr(__import__('json').loads('3.141592653589793238462643383279')) == '3.141592653589793'
    assert pyrt.repr(loads('3.141592653589793238462643383279')!) == '3.141592653589793'
}

fn test_dumps_values() {
    check_dumps_values() or { assert false, err.msg() }
}

fn check_dumps_values() ! {
    // python: __import__('json').dumps(None) == 'null'
    assert dumps(pyrt.none_, DumpOptions{})! == 'null'
    // python: __import__('json').dumps(True) == 'true'
    assert dumps(pyrt.Value(true), DumpOptions{})! == 'true'
    // python: __import__('json').dumps(False) == 'false'
    assert dumps(pyrt.Value(false), DumpOptions{})! == 'false'
    // python: __import__('json').dumps(42) == '42'
    assert dumps(pyrt.Value(i64(42)), DumpOptions{})! == '42'
    // python: __import__('json').dumps(1.0) == '1.0'
    assert dumps(pyrt.Value(1.0), DumpOptions{})! == '1.0'
    // python: __import__('json').dumps(-0.0) == '-0.0'
    assert dumps(pyrt.Value(-0.0), DumpOptions{})! == '-0.0'
    // python: __import__('json').dumps(float('inf')) == 'Infinity'
    assert dumps(loads('Infinity')!, DumpOptions{})! == 'Infinity'
    // python: __import__('json').dumps(float('nan')) == 'NaN'
    assert dumps(loads('NaN')!, DumpOptions{})! == 'NaN'
    // python: __import__('json').dumps(['a',1,None]) == '["a", 1, null]'
    assert dumps(pyrt.Value(pyrt.new_list([pyrt.Value('a'), pyrt.Value(i64(1)), pyrt.none_])), DumpOptions{})! == '["a", 1, null]'
    // python: __import__('json').dumps(('a',1)) == '["a", 1]'
    assert dumps(pyrt.Value(pyrt.new_tuple([pyrt.Value('a'), pyrt.Value(i64(1))])), DumpOptions{})! == '["a", 1]'
    // python: __import__('json').dumps('a\nb') == '"a\\nb"'
    assert dumps(pyrt.Value('a\nb'), DumpOptions{})! == '"a\\nb"'
    // python: __import__('json').dumps('é🙂') == '"\\u00e9\\ud83d\\ude42"'
    assert dumps(pyrt.Value('é🙂'), DumpOptions{})! == '"\\u00e9\\ud83d\\ude42"'
    // python: __import__('json').dumps('é🙂', ensure_ascii=False) == '"é🙂"'
    assert dumps(pyrt.Value('é🙂'), DumpOptions{ensure_ascii: false})! == '"é🙂"'
    // python: __import__('json').dumps('<>') == '"<>"'
    assert dumps(pyrt.Value('<>'), DumpOptions{})! == '"<>"'
}

fn test_dumps_dict_options() {
    check_dumps_dict_options() or { assert false, err.msg() }
}

fn check_dumps_dict_options() ! {
    obj := make_dict([pyrt.Value('b'), pyrt.Value('a')], [pyrt.Value(i64(2)), pyrt.Value(i64(1))])!
    // python: __import__('json').dumps({'b':2,'a':1}) == '{"b": 2, "a": 1}'
    assert dumps(obj, DumpOptions{})! == '{"b": 2, "a": 1}'
    // python: __import__('json').dumps({'b':2,'a':1}, sort_keys=True) == '{"a": 1, "b": 2}'
    assert dumps(obj, DumpOptions{sort_keys: true})! == '{"a": 1, "b": 2}'
    // python: __import__('json').dumps({'b':2,'a':1}, separators=(',', ':')) == '{"b":2,"a":1}'
    assert dumps(obj, DumpOptions{separators: [',', ':']})! == '{"b":2,"a":1}'
    // python: __import__('json').dumps({'b':2,'a':1}, indent=2) == '{\n  "b": 2,\n  "a": 1\n}'
    assert dumps(obj, DumpOptions{indent: 2})! == '{\n  "b": 2,\n  "a": 1\n}'
    // python: __import__('json').dumps({'b':2,'a':1}, indent=0) == '{\n"b": 2,\n"a": 1\n}'
    assert dumps(obj, DumpOptions{indent: 0})! == '{\n"b": 2,\n"a": 1\n}'
    // python: __import__('json').dumps({'b':2,'a':1}, indent=-1) == '{\n"b": 2,\n"a": 1\n}'
    assert dumps(obj, DumpOptions{indent: -1})! == '{\n"b": 2,\n"a": 1\n}'
    // python: __import__('json').dumps({'b':2,'a':1}, indent=2, separators=(',', ':')) == '{\n  "b":2,\n  "a":1\n}'
    assert dumps(obj, DumpOptions{indent: 2, separators: [',', ':']})! == '{\n  "b":2,\n  "a":1\n}'
    numeric_keys := make_dict([pyrt.Value(true), pyrt.none_], [pyrt.Value(i64(1)), pyrt.Value(i64(2))])!
    // python: __import__('json').dumps({True:1,None:2}) == '{"true": 1, "null": 2}'
    assert dumps(numeric_keys, DumpOptions{})! == '{"true": 1, "null": 2}'
    // python: __import__('json').dumps({"a":[1,2]}, indent=2) == '{\n  "a": [\n    1,\n    2\n  ]\n}'
    nested := make_dict([pyrt.Value('a')], [pyrt.Value(pyrt.new_list([pyrt.Value(i64(1)), pyrt.Value(i64(2))]))])!
    assert dumps(nested, DumpOptions{indent: 2})! == '{\n  "a": [\n    1,\n    2\n  ]\n}'
}

fn test_json_errors() {
    check_json_errors() or { assert false, err.msg() }
}

fn check_json_errors() ! {
    // python: str(__import__('json').JSONDecodeError('Expecting value', '', 0)) == 'Expecting value: line 1 column 1 (char 0)'
    assert decode_error_text('') == 'JSONDecodeError|Expecting value: line 1 column 1 (char 0)'
    // python: str(__import__('json').JSONDecodeError('Extra data', '1 2', 2)) == 'Extra data: line 1 column 3 (char 2)'
    assert decode_error_text('1 2') == 'JSONDecodeError|Extra data: line 1 column 3 (char 2)'
    // python: str(__import__('json').JSONDecodeError('Illegal trailing comma before end of array', '[1,]', 2)) == 'Illegal trailing comma before end of array: line 1 column 3 (char 2)'
    assert decode_error_text('[1,]') == 'JSONDecodeError|Illegal trailing comma before end of array: line 1 column 3 (char 2)'
    // python: str(__import__('json').JSONDecodeError('Expecting property name enclosed in double quotes', '{bad}', 1)) == 'Expecting property name enclosed in double quotes: line 1 column 2 (char 1)'
    assert decode_error_text('{bad}') == 'JSONDecodeError|Expecting property name enclosed in double quotes: line 1 column 2 (char 1)'
    // python: str(__import__('json').JSONDecodeError('Invalid \\escape', '"\\q"', 1)) == 'Invalid \\escape: line 1 column 2 (char 1)'
    assert decode_error_text('"\\q"') == 'JSONDecodeError|Invalid \\escape: line 1 column 2 (char 1)'
    // python: error_text(lambda: __import__('json').dumps(set())) == 'TypeError|Object of type set is not JSON serializable'
    assert encode_error_text(pyrt.Value(pyrt.new_set([]pyrt.Value{})!), DumpOptions{}) == 'TypeError|Object of type set is not JSON serializable'
    // python: error_text(lambda: __import__('json').dumps(float('nan'), allow_nan=False)) == 'ValueError|Out of range float values are not JSON compliant: nan'
    assert encode_error_text(loads('NaN')!, DumpOptions{allow_nan: false}) == 'ValueError|Out of range float values are not JSON compliant: nan'
    // runtime: create a self-referential List for the following assertion
    cyclic := pyrt.new_list([]pyrt.Value{})
    unsafe { cyclic.items << pyrt.Value(cyclic) }
    // python: error_text(lambda: exec_result('a=[]; a.append(a)', "__import__('json').dumps(a)")) == 'ValueError|Circular reference detected'
    assert encode_error_text(pyrt.Value(cyclic), DumpOptions{}) == 'ValueError|Circular reference detected'
}

fn test_json_file_paths() {
    check_json_file_paths() or { assert false, err.msg() }
}

fn check_json_file_paths() ! {
    path := os.join_path(os.vtmp_dir(), 'pyrt_json_v_test.json')
    defer { os.rm(path) or {} }
    values := pyrt.Value(pyrt.new_list([pyrt.Value('a'), pyrt.Value(i64(12))]))
    dump_to(values, path, DumpOptions{})!
    // python: __import__('json').dumps(['a',12]) == '["a", 12]'
    assert os.read_file(path)! == '["a", 12]'
    // python: repr(__import__('json').loads('["a", 12]')) == "['a', 12]"
    assert pyrt.repr(load(path)!) == "['a', 12]"
}

fn make_dict(keys []pyrt.Value, values []pyrt.Value) !pyrt.Value {
    obj := pyrt.Value(pyrt.new_dict())
    for i, key in keys { pyrt.setitem(obj, key, values[i])! }
    return obj
}

fn decode_error_text(source string) string {
    _ = loads(source) or {
        if err is pyrt.PyError { return err.class_name + '|' + err.msg() }
        return 'VError|' + err.msg()
    }
    return '<no error>'
}

fn encode_error_text(v pyrt.Value, opts DumpOptions) string {
    _ = dumps(v, opts) or {
        if err is pyrt.PyError { return err.class_name + '|' + err.msg() }
        return 'VError|' + err.msg()
    }
    return '<no error>'
}
