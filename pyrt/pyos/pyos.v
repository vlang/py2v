module pyos

import os
import pyrt

// environ returns a snapshot of the process environment.
pub fn environ() map[string]string { return os.environ() }

// environ_get returns the environment value or the supplied default.
pub fn environ_get(name string, default_value string) string {
	return os.getenv_opt(name) or { default_value }
}

// getenv returns none when the environment variable is missing.
pub fn getenv(name string) ?string {
	return os.getenv_opt(name)
}

// getenv_or returns the environment value or the supplied default.
pub fn getenv_or(name string, default_value string) string {
	return os.getenv_opt(name) or { default_value }
}

// path_join joins POSIX path components.
pub fn path_join(base string, parts ...string) string {
	mut result := base
	for part in parts {
		if part == '' { continue }
		if part[0] == 47 {
			result = part
		} else if result == '' {
			result = part
		} else if result.len > 0 && result[result.len - 1] == 47 {
			result = result + part
		} else {
			result = result + '/' + part
		}
	}
	return result
}

// path_exists reports whether the path exists.
pub fn path_exists(path string) bool { return os.exists(path) }

// path_isfile reports whether the path points to a file.
pub fn path_isfile(path string) bool { return os.is_file(path) }

// path_isdir reports whether the path points to a directory.
pub fn path_isdir(path string) bool { return os.is_dir(path) }

// path_dirname returns the directory component of a POSIX path.
pub fn path_dirname(path string) string {
	last := path.last_index('/') or { return '' }
	head := path[..last + 1]
	trimmed := head.trim_right('/')
	return if trimmed == '' { head } else { trimmed }
}

// path_basename returns the last component of the path.
pub fn path_basename(path string) string { return os.base(path) }

// path_expanduser expands the path's leading tilde.
pub fn path_expanduser(path string) string { return os.expand_tilde_to_home(path) }

// path_abspath returns the absolute path.
pub fn path_abspath(path string) string { return os.abs_path(path) }

// getcwd returns the process's working directory.
pub fn getcwd() string { return os.getwd() }

// makedirs creates a directory and any missing parents.
pub fn makedirs(path string, exist_ok bool) ! {
	if os.exists(path) {
		if !os.is_dir(path) {
			return pyrt.raise('FileExistsError', "[Errno 17] File exists: '${path}'")
		}
		if exist_ok { return }
		return pyrt.raise('FileExistsError', "[Errno 17] File exists: '${path}'")
	}
	os.mkdir_all(path, os.MkdirParams{}) or { return pyrt.raise('OSError', err.msg()) }
}

// listdir returns the names of the entries in the directory.
pub fn listdir(path string) ![]string {
	if !os.exists(path) {
		return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'")
	}
	if !os.is_dir(path) {
		return pyrt.raise('NotADirectoryError', "[Errno 20] Not a directory: '${path}'")
	}
	return os.ls(path) or { return pyrt.raise('OSError', err.msg()) }
}

// remove removes a file.
pub fn remove(path string) ! {
	if !os.exists(path) {
		return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'")
	}
	if os.is_dir(path) {
		return pyrt.raise('IsADirectoryError', "[Errno 21] Is a directory: '${path}'")
	}
	os.rm(path) or { return pyrt.raise('OSError', err.msg()) }
}

// rmdir removes an empty directory.
pub fn rmdir(path string) ! {
	if !os.exists(path) {
		return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'")
	}
	if !os.is_dir(path) {
		return pyrt.raise('NotADirectoryError', "[Errno 20] Not a directory: '${path}'")
	}
	os.rmdir(path) or { return pyrt.raise('OSError', err.msg()) }
}

// getpid returns an error because the pinned vlib API lacks a process ID accessor.
pub fn getpid() !int {
	return pyrt.raise('NotImplementedError', 'getpid requires a process-ID API absent from the supplied V reference')
}
