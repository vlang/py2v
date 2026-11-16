module pyos

import pyrt

fn test_round8_process_environ_mapping() {
    name := 'PYRT_R8_ENVIRON_TEST_KEY_6317'
    unsetenv(name)
    defer { unsetenv(name) }
    // python: 'ABSENT' not in {'PRESENT':'value'}
    assert !environ_has(name)
    putenv(name, 'first')
    // python: {'PRESENT':'first'}['PRESENT'] == 'first'
    assert environ_item(name) == 'first'
    // python: 'PRESENT' in {'PRESENT':'first'}
    assert environ_has(name)
    // python: {'PRESENT':'first'}.setdefault('PRESENT','second') == 'first'
    assert environ_setdefault(name, 'second') == 'first'
    // python: {'PRESENT':'first'}.copy()['PRESENT'] == 'first'
    snapshot := environ()
    assert snapshot[name] == 'first'
    environ_delete(name)
    // python: 'PRESENT' not in {}
    assert !environ_has(name)
    // python: {}.setdefault('PRESENT','new') == 'new'
    assert environ_setdefault(name, 'new') == 'new'
    // python: {'PRESENT':'new'}['PRESENT'] == 'new'
    assert environ_item(name) == 'new'
    // python: {'PRESENT':'new'}.pop('PRESENT',None) == 'new'
    unsetenv(name)
    // runtime: environment deletion is observable through getenv_opt.
    assert !environ_has(name)
}
