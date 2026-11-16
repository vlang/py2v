module pyos

import os
import pyrt

// Python os + os.path call targets. POSIX path semantics only.

pub fn environ() map[string]string { return os.environ() }

pub fn environ_get(name string, default_value string) string {
    return os.getenv_opt(name) or { default_value }
}

// Unlike V's os.getenv, missing Python getenv() is None, not ''.
pub fn getenv(name string) ?string {
    return os.getenv_opt(name)
}

pub fn getenv_or(name string, default_value string) string {
    return os.getenv_opt(name) or { default_value }
}

pub fn path_join(base string, parts ...string) string {
    mut result := base
    for part in parts {
        if part == '' { continue }
        if part[0] == 47 {
            result = part
        } else if result == '' {
            result = part
        } else if (result.len > 0 && result[result.len - 1] == 47) {
            result = result + part
        } else {
            result = result + '/' + part
        }
    }
    return result
}

pub fn path_exists(path string) bool { return os.exists(path) }
pub fn path_isfile(path string) bool { return os.is_file(path) }
pub fn path_isdir(path string) bool { return os.is_dir(path) }
pub fn path_dirname(path string) string { return os.dir(path) }
pub fn path_basename(path string) string { return os.base(path) }
pub fn path_expanduser(path string) string { return os.expand_tilde_to_home(path) }
pub fn path_abspath(path string) string { return os.abs_path(path) }
pub fn getcwd() string { return os.getwd() }

pub fn makedirs(path string, exist_ok bool) ! {
    if os.exists(path) {
        if !os.is_dir(path) { return pyrt.raise('FileExistsError', "[Errno 17] File exists: '${path}'") }
        if exist_ok { return }
        return pyrt.raise('FileExistsError', "[Errno 17] File exists: '${path}'")
    }
    os.mkdir_all(path, os.MkdirParams{}) or { return pyrt.raise('OSError', err.msg()) }
}

pub fn listdir(path string) ![]string {
    if !os.exists(path) { return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'") }
    if !os.is_dir(path) { return pyrt.raise('NotADirectoryError', "[Errno 20] Not a directory: '${path}'") }
    return os.ls(path) or { return pyrt.raise('OSError', err.msg()) }
}

pub fn remove(path string) ! {
    if !os.exists(path) { return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'") }
    if os.is_dir(path) { return pyrt.raise('IsADirectoryError', "[Errno 21] Is a directory: '${path}'") }
    os.rm(path) or { return pyrt.raise('OSError', err.msg()) }
}

pub fn rmdir(path string) ! {
    if !os.exists(path) { return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'") }
    if !os.is_dir(path) { return pyrt.raise('NotADirectoryError', "[Errno 20] Not a directory: '${path}'") }
    os.rmdir(path) or { return pyrt.raise('OSError', err.msg()) }
}

// No process-ID accessor appears in the supplied vlib signatures. Inventing
// os.getpid or importing C would violate the pinned-reference contract.
pub fn getpid() !int {
    return pyrt.raise('NotImplementedError', 'getpid requires a process-ID API absent from the supplied V reference')
}
