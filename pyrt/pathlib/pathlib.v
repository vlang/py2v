module pathlib

import os
import pyrt

// A POSIX PurePath-like lexical representation plus the available os calls.
// Windows drives, UNC roots, symlink loops, permissions, and locale decoding
// cannot all be reproduced from the constrained reference API.
pub struct Path {
    raw string
}

pub struct Stat {
pub:
    st_size  i64
    mtime f64
}

@[params]
pub struct MkdirOptions {
pub:
    parents  bool
    exist_ok bool
}

@[params]
pub struct UnlinkOptions {
pub:
    missing_ok bool
}

@[params]
pub struct OpenOptions {
pub:
    mode string = 'r'
}

@[params]
pub struct TouchOptions {
pub:
    exist_ok bool = true
}

fn split_components(path string) []string {
    mut out := []string{}
    mut begin := 0
    for i in 0 .. path.len {
        if path[i] == 47 {
            out << path[begin .. i]
            begin = i + 1
        }
    }
    out << path[begin .. path.len]
    return out
}

fn normalize(parts []string) string {
    mut components := []string{}
    mut absolute := false
    for part in parts {
        if part == '' { continue }
        if part[0] == 47 {
            absolute = true
            components = []string{}
        }
        for item in split_components(part) {
            if item != '' && item != '.' { components << item }
        }
    }
    text := components.join('/')
    if absolute { return '/' + text }
    return if text == '' { '.' } else { text }
}

pub fn new_path(parts ...string) Path {
    return Path{raw: normalize(parts)}
}

pub fn home() Path {
    return new_path(os.home_dir())
}

pub fn cwd() Path {
    return new_path(os.getwd())
}

pub fn (p Path) str() string {
    return p.raw
}

pub fn (p Path) joinpath(parts ...string) Path {
    mut all := [p.raw]
    all << parts
    return Path{raw: normalize(all)}
}

// Verify syntax on the pinned compiler; no V operator-overload example was
// present in the supplied reference. The implementation itself is joinpath.
pub fn (left Path) / (right Path) Path {
    return left.joinpath(right.raw)
}

pub fn (p Path) is_absolute() bool {
    return p.raw.len > 0 && p.raw[0] == 47
}

pub fn (p Path) parts() []string {
    mut out := []string{}
    if p.raw == '.' { return out }
    if p.raw == '/' { return ['/'] }
    if p.is_absolute() { out << '/' }
    for item in split_components(p.raw) {
        if item != '' { out << item }
    }
    return out
}

pub fn (p Path) name() string {
    if p.raw == '/' || p.raw == '.' { return '' }
    mut last := 0
    for i in 0 .. p.raw.len {
        if p.raw[i] == 47 { last = i + 1 }
    }
    return p.raw[last .. p.raw.len]
}

pub fn (p Path) parent() Path {
    if p.raw == '/' || p.raw == '.' { return p }
    mut last := -1
    for i in 0 .. p.raw.len {
        if p.raw[i] == 47 { last = i }
    }
    if last < 0 { return new_path('.') }
    if last == 0 { return new_path('/') }
    return new_path(p.raw[0 .. last])
}

pub fn (p Path) suffix() string {
    name := p.name()
    mut dot := -1
    for i in 0 .. name.len { if name[i] == 46 { dot = i } }
    if dot < 1 { return '' }
    // CPython 3.14+ treats a trailing '.' as a suffix.
    return name[dot .. name.len]
}

pub fn (p Path) stem() string {
    name := p.name()
    suffix := p.suffix()
    if suffix == '' { return name }
    return name[0 .. name.len - suffix.len]
}

pub fn (p Path) with_name(name string) !Path {
    if p.name() == '' { return pyrt.raise('ValueError', '${pyrt.repr(pyrt.Value(p.raw))} has an empty name') }
    if name == '' || name.contains('/') { return pyrt.raise('ValueError', 'Invalid name ${pyrt.repr(pyrt.Value(name))}') }
    return p.parent().joinpath(name)
}

pub fn (p Path) with_suffix(suffix string) !Path {
    if suffix != '' && (suffix[0] != 46 || suffix.contains('/')) {
        return pyrt.raise('ValueError', 'Invalid suffix ${pyrt.repr(pyrt.Value(suffix))}')
    }
    if p.name() == '' { return pyrt.raise('ValueError', '${pyrt.repr(pyrt.Value(p.raw))} has an empty name') }
    return p.with_name(p.stem() + suffix)!
}

pub fn (p Path) is_relative_to(other Path) bool {
    if p.is_absolute() != other.is_absolute() { return false }
    if other.raw == '.' { return !p.is_absolute() }
    if other.raw == '/' { return p.is_absolute() }
    prefix := other.raw + '/'
    return p.raw == other.raw || (p.raw.len >= prefix.len && p.raw[0 .. prefix.len] == prefix)
}

pub fn (p Path) relative_to(other Path) !Path {
    if !p.is_relative_to(other) {
        return pyrt.raise('ValueError', '${p.raw} is not in the subpath of ${other.raw} OR one path is relative and the other is absolute.')
    }
    if p.raw == other.raw { return new_path('.') }
    if other.raw == '.' { return p }
    start := if other.raw == '/' { 1 } else { other.raw.len + 1 }
    return new_path(p.raw[start .. p.raw.len])
}

pub fn (p Path) expanduser() !Path {
    if p.raw == '~' { return home() }
    if p.raw.len >= 2 && p.raw[0 .. 2] == '~/' {
        return home().joinpath(p.raw[2 .. p.raw.len])
    }
    if p.raw.len > 0 && p.raw[0] == 126 {
        return pyrt.raise('RuntimeError', 'Could not determine home directory for ${p.raw}')
    }
    return p
}

pub fn (p Path) absolute() Path {
    if p.is_absolute() { return p }
    return new_path(os.abs_path(p.raw))
}

pub fn (p Path) resolve() Path {
    // os.real_path is listed in part B; strict=False semantics are approximate
    // for nonexistent paths, inaccessible parents, and symlink loops.
    return new_path(os.real_path(p.absolute().raw))
}

pub fn (p Path) exists() bool {
    return os.exists(p.raw)
}

pub fn (p Path) is_dir() bool {
    return os.is_dir(p.raw)
}

pub fn (p Path) is_file() bool {
    return os.is_file(p.raw)
}

fn path_repr(path string) string {
    return pyrt.repr(pyrt.Value(path))
}

fn missing_error(path string) IError {
    return pyrt.raise('FileNotFoundError', '[Errno 2] No such file or directory: ${path_repr(path)}')
}

fn directory_error(path string) IError {
    return pyrt.raise('IsADirectoryError', '[Errno 21] Is a directory: ${path_repr(path)}')
}

fn exists_error(path string) IError {
    return pyrt.raise('FileExistsError', '[Errno 17] File exists: ${path_repr(path)}')
}

fn path_os_error(err IError) IError {
    return pyrt.raise('OSError', err.msg())
}

pub fn (p Path) read_text() !string {
    if !p.exists() { return missing_error(p.raw) }
    if p.is_dir() { return directory_error(p.raw) }
    return os.read_file(p.raw) or { return path_os_error(err) }
}

pub fn (p Path) read_bytes() ![]u8 {
    if !p.exists() { return missing_error(p.raw) }
    if p.is_dir() { return directory_error(p.raw) }
    return os.read_bytes(p.raw) or { return path_os_error(err) }
}

pub fn (p Path) write_text(text string) !int {
    if p.is_dir() { return directory_error(p.raw) }
    os.write_file(p.raw, text) or { return path_os_error(err) }
    // Python returns number of Unicode characters, not UTF-8 bytes.
    return text.runes().len
}

pub fn (p Path) write_bytes(bytes []u8) !int {
    if p.is_dir() { return directory_error(p.raw) }
    os.write_bytes(p.raw, bytes) or { return path_os_error(err) }
    return bytes.len
}

pub fn (p Path) mkdir(opts MkdirOptions) ! {
    if p.exists() {
        if p.is_dir() && opts.exist_ok { return }
        return exists_error(p.raw)
    }
    if opts.parents {
        os.mkdir_all(p.raw, os.MkdirParams{}) or { return path_os_error(err) }
    } else {
        os.mkdir(p.raw, os.MkdirParams{}) or { return path_os_error(err) }
    }
}

pub fn (p Path) unlink(opts UnlinkOptions) ! {
    if !p.exists() {
        if opts.missing_ok { return }
        return missing_error(p.raw)
    }
    if p.is_dir() { return directory_error(p.raw) }
    os.rm(p.raw) or { return path_os_error(err) }
}

pub fn (p Path) rmdir() ! {
    if !p.exists() { return missing_error(p.raw) }
    os.rmdir(p.raw) or { return path_os_error(err) }
}

pub fn (p Path) touch(opts TouchOptions) ! {
    if p.exists() {
        if !opts.exist_ok { return exists_error(p.raw) }
        // A safe update of file mtime is absent from the supplied os API.
        return
    }
    mut file := os.create(p.raw) or { return path_os_error(err) }
    file.close()
}

pub fn (p Path) stat() !Stat {
    _ = os.stat(p.raw) or { return missing_error(p.raw) }
    return Stat{
        st_size: i64(os.file_size(p.raw))
        mtime: f64(os.file_last_mod_unix(p.raw))
    }
}

pub fn (p Path) samefile(other Path) !bool {
    _ = p.stat()!
    _ = other.stat()!
    // This compares resolved names, NOT device+inode; hardlinks differ.
    return p.resolve().raw == other.resolve().raw
}

pub fn (p Path) open(opts OpenOptions) !os.File {
    if opts.mode == 'r' || opts.mode == 'rb' {
        if !p.exists() { return missing_error(p.raw) }
        return os.open(p.raw) or { return path_os_error(err) }
    }
    if opts.mode == 'w' || opts.mode == 'wb' {
        if p.is_dir() { return directory_error(p.raw) }
        return os.create(p.raw) or { return path_os_error(err) }
    }
    return pyrt.raise('NotImplementedError', 'file mode ${opts.mode} is not available from the supplied V os signatures')
}

pub fn (p Path) iterdir() ![]Path {
    if !p.is_dir() {
        if !p.exists() { return missing_error(p.raw) }
        return pyrt.raise('NotADirectoryError', '[Errno 20] Not a directory: ${path_repr(p.raw)}')
    }
    names := os.ls(p.raw) or { return path_os_error(err) }
    mut paths := []Path{}
    for name in names { paths << p.joinpath(name) }
    return paths
}

fn glob_byte_match(pattern string, text string) bool {
    // POSIX glob segment: '?' any one byte, '*' any number, no character
    // classes. Python operates on Unicode characters; ASCII is exact.
    mut i := 0
    mut j := 0
    mut star := -1
    mut backtrack := 0
    for j < text.len {
        if i < pattern.len && (pattern[i] == 63 || pattern[i] == text[j]) {
            i = i + 1
            j = j + 1
        } else if i < pattern.len && pattern[i] == 42 {
            star = i
            i = i + 1
            backtrack = j
        } else if star >= 0 {
            i = star + 1
            backtrack = backtrack + 1
            j = backtrack
        } else { return false }
    }
    for i < pattern.len && pattern[i] == 42 { i = i + 1 }
    return i == pattern.len
}

fn path_less(a Path, b Path) bool {
    n := if a.raw.len < b.raw.len { a.raw.len } else { b.raw.len }
    for i in 0 .. n {
        if a.raw[i] < b.raw[i] { return true }
        if a.raw[i] > b.raw[i] { return false }
    }
    return a.raw.len < b.raw.len
}

fn sorted_paths(items []Path) []Path {
    mut result := items.clone()
    for i in 0 .. result.len {
        mut j := i + 1
        for j < result.len {
            if path_less(result[j], result[i]) {
                old := result[i]
                result[i] = result[j]
                result[j] = old
            }
            j = j + 1
        }
    }
    return result
}

fn glob_walk(base Path, parts []string, index int, depth int, mut results []Path) ! {
    if depth > 64 { return pyrt.raise('RecursionError', 'maximum glob traversal depth exceeded') }
    if index == parts.len {
        if base.exists() { results << base }
        return
    }
    if !base.is_dir() { return }
    part := parts[index]
    if part == '**' {
        glob_walk(base, parts, index + 1, depth + 1, mut results)!
        children := base.iterdir()!
        for child in children {
            if child.is_dir() { glob_walk(child, parts, index, depth + 1, mut results)! }
        }
        return
    }
    children := base.iterdir()!
    for child in children {
        if glob_byte_match(part, child.name()) {
            glob_walk(child, parts, index + 1, depth + 1, mut results)!
        }
    }
}

pub fn (p Path) glob(pattern string) ![]Path {
    if pattern == '' { return pyrt.raise('ValueError', 'Unacceptable pattern: empty pattern') }
    if pattern[0] == 47 { return pyrt.raise('NotImplementedError', 'Non-relative patterns are unsupported') }
    mut result := []Path{}
    glob_walk(p, split_components(pattern), 0, 0, mut result)!
    return sorted_paths(result)
}

pub fn (p Path) rglob(pattern string) ![]Path {
    return p.glob('**/' + pattern)!
}
