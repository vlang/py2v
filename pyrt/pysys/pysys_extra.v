module pysys

import os

// These are compatibility values for a py2v application, NOT the host's
// CPython installation. The target version can be overridden at the source
// level until py2v supplies its own runtime configuration.
pub const maxsize = i64(9223372036854775807)

pub struct VersionInfo {
pub:
    major int
    minor int
}

pub fn version_info() VersionInfo {
    // The CPython release whose behavior this runtime follows.
    return VersionInfo{major: 3, minor: 15}
}

pub fn platform() string {
    // Override when a transpiled binary runs on another host.
    if value := os.getenv_opt('PYRT_SYS_PLATFORM') { return value }
    return 'darwin'
}

pub fn path() []string {
    mut entries := [os.getwd()]
    if env_path := os.getenv_opt('PYTHONPATH') {
        mut start := 0
        mut i := 0
        for i <= env_path.len {
            if i == env_path.len || env_path[i] == 58 {
                entry := env_path[start .. i]
                entries << (if entry == '' { os.getwd() } else { entry })
                start = i + 1
            }
            i = i + 1
        }
    }
    return entries
}

pub fn getrecursionlimit() int { return 1000 }

pub fn setrecursionlimit(n int) ! {
    // Deliberate no-op: V's call-stack limit is not CPython's frame budget.
    _ = n
}
