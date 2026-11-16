module random

import pyrt

fn test_random_ranges_and_seed_reuse() {
    seed(42)
    a := random()
    // python: 0.0 <= __import__('random').random() < 1.0
    assert a >= 0.0 && a < 1.0
    n := randint(2, 4) or { -1 }
    // python: 2 <= __import__('random').randint(2,4) <= 4
    assert n >= 2 && n <= 4
    u := uniform(-1.0, 1.0)
    // python: -1 <= __import__('random').uniform(-1,1) <= 1
    assert u >= -1.0 && u <= 1.0
    seed(42)
    b := random()
    seed(42)
    c := random()
    // python: (__import__('random').seed(42), __import__('random').random())[1] == (__import__('random').seed(42), __import__('random').random())[1]
    assert b == c
}

fn test_random_choice_and_shuffle() {
    values := [pyrt.Value('a'), pyrt.Value('b'), pyrt.Value('c')]
    selected := choice(values) or { panic(err.msg()) }
    // python: __import__('random').choice(['a','b','c']) in ['a','b','c']
    assert pyrt.contains(pyrt.Value(pyrt.new_list(values)), selected) or { false }
    mut shuffled := values.clone()
    shuffle(mut shuffled) or { panic(err.msg()) }
    // python: sorted(['a', 'b', 'c']) == ['a','b','c']
    assert shuffled.len == 3
    // python: len(__import__('random').choices([1,2], k=5)) == 5
    assert (choices(values, 5) or { []pyrt.Value{} }).len == 5
}
