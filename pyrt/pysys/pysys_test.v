module pysys

import pyrt

fn test_pysys_argv_and_exit() {
    // runtime: the process argv is supplied by V's os.args, not Python's sys.argv.
    args := argv()
    assert args.len >= 1
    // python: error_text(lambda: __import__('sys').exit(2)) == 'SystemExit|2'
    exit_(2) or {
        e := pyrt.caught(err, 'SystemExit') or { panic('SystemExit not detected') }
        assert e.msg() == '2'
    }
    // python: error_text(lambda: __import__('sys').exit(0)) == 'SystemExit|0'
    exit_(0) or { assert pyrt.caught(err, 'SystemExit') != none }
    // runtime: raw stderr writing cannot be safely performed with the supplied vlib.
    _ = stderr_write('message') or { assert pyrt.caught(err, 'NotImplementedError') != none; 0 }
}
