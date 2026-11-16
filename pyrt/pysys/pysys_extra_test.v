module pysys

fn test_system_compatibility_metadata() {
    // python: __import__('sys').maxsize == 9223372036854775807
    assert maxsize == i64(9223372036854775807)
    // runtime: target Python release is configured for the user's CPython 3.15.
    version := version_info()
    assert version.major == 3 && version.minor == 15
    // runtime: default sys.platform is configured for macOS, override via PYRT_SYS_PLATFORM.
    assert platform() != ''
    // runtime: PYTHONPATH and cwd provide a partial sys.path.
    assert path().len >= 1
    // python: __import__('sys').getrecursionlimit() >= 100
    assert getrecursionlimit() == 1000
    // runtime: setrecursionlimit is a deliberate no-op.
    setrecursionlimit(200) or { panic(err.msg()) }
    assert getrecursionlimit() == 1000
}
