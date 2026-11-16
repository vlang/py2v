module pytime

import pyrt

fn test_pytime_clocks_and_sleep() {
    // python: isinstance(__import__('time').time(), float)
    stamp := time_()
    assert stamp > 1000000000.0
    // python: __import__('time').monotonic() > 0
    a := monotonic()
    assert a >= 0.0
    // python: __import__('time').perf_counter() > 0
    b := perf_counter()
    assert b >= 0.0
    // python: __import__('time').sleep(0) is None
    sleep(0.0) or { panic(err.msg()) }
    // python: error_text(lambda: __import__('time').sleep(-1.0)) == 'ValueError|sleep length must be non-negative'
    sleep(-1.0) or { assert err.msg() == 'sleep length must be non-negative' }
    // runtime: clock advances monotonically on this host.
    assert monotonic() >= a
}
