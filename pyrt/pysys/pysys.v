module pysys

import os
import pyrt

// os.args is the V process's argument vector. It is NOT guaranteed to match
// Python's original sys.argv when launched by a transpiler driver.
pub fn argv() []string { return os.args.clone() }

// Returning an error models Python sys.exit raising SystemExit (including 0).
// py2v must propagate the result: pysys.exit_(status)!
pub fn exit_(code int) ! {
    return IError(pyrt.exception('SystemExit', [pyrt.Value(i64(code))]))
}

pub fn stdout_write(s string) int {
    print(s)
    return s.len
}

// No exact raw stderr output entry point is exposed by the supplied os API.
// Avoid silently redirecting diagnostics to stdout or adding a newline.
pub fn stderr_write(_ string) !int {
    return pyrt.raise('NotImplementedError', 'raw stderr output requires an API absent from the supplied V reference')
}

// os.get_raw_line is the only stdin read API in the supplied reference. It
// cannot establish EOF reliably or emulate read(size)/read() for all inputs.
pub fn stdin_readline() string { return os.get_raw_line() }

pub fn stdin_read() string {
    return os.get_raw_line()
}
