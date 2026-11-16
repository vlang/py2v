module pyos

import os
import pyrt

// Expanded POSIX os.path and os APIs. All public signatures depend only on
// the vlib os functions listed in the pinned reference.

pub const sep = '/'
pub const linesep = '\n'

pub struct PathStat {
pub:
    st_size i64
    mtime f64
}

pub struct WalkEntry {
pub:
    dirpath string
    dirnames []string
    filenames []string
}

pub fn path_splitext(path string) (string, string) {
    mut slash := -1
    mut dot := -1
    for i in 0 .. path.len {
        if path[i] == 47 { slash = i }
        if path[i] == 46 { dot = i }
    }
    if dot <= slash + 1 { return path, '' }
    mut ordinary := false
    for i in slash + 1 .. dot {
        if path[i] != 46 { ordinary = true; break }
    }
    if !ordinary { return path, '' }
    return path[0 .. dot], path[dot .. path.len]
}

pub fn path_getsize(path string) !i64 {
    if !os.exists(path) {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'")
    }
    return i64(os.file_size(path))
}

pub fn path_realpath(path string) string {
    return os.real_path(path)
}

// Normalize a POSIX absolute path lexically. Python relpath uses normpath
// rather than resolving symlinks.
fn path_components(path string) []string {
    mut parts := []string{}
    mut start := 0
    mut i := 0
    for i <= path.len {
        if i == path.len || path[i] == 47 {
            part := path[start .. i]
            if part == '..' {
                if parts.len > 0 { _ = parts.pop() }
            } else if part != '' && part != '.' {
                parts << part
            }
            start = i + 1
        }
        i = i + 1
    }
    return parts
}

pub fn path_relpath(path string, start string) !string {
    if path == '' { return pyrt.raise('ValueError', 'no path specified') }
    abs_target := os.abs_path(path)
    abs_start := os.abs_path(if start == '' { '.' } else { start })
    left := path_components(abs_start)
    right := path_components(abs_target)
    mut shared := 0
    for shared < left.len && shared < right.len {
        if left[shared] != right[shared] { break }
        shared = shared + 1
    }
    mut output := []string{}
    for _ in shared .. left.len { output << '..' }
    for i in shared .. right.len { output << right[i] }
    return if output.len == 0 { '.' } else { output.join('/') }
}

pub fn stat(path string) !PathStat {
    if !os.exists(path) {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'")
    }
    return PathStat{st_size: i64(os.file_size(path)), mtime: f64(os.file_last_mod_unix(path))}
}

// A limited regular-file-only emulation. No rename syscall exists in the
// supplied V reference. This is NOT atomic, does not preserve metadata or
// hardlinks, and cannot replace directories/symlinks correctly.
fn copy_then_remove(source string, dest string) ! {
    if !os.exists(source) {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${source}'")
    }
    if os.is_dir(source) || os.is_dir(dest) {
        return pyrt.raise('NotImplementedError', 'directory rename requires an unavailable atomic filesystem API')
    }
    if os.abs_path(source) == os.abs_path(dest) { return }
    contents := os.read_bytes(source) or { return pyrt.raise('OSError', err.msg()) }
    os.write_bytes(dest, contents) or { return pyrt.raise('OSError', err.msg()) }
    os.rm(source) or { return pyrt.raise('OSError', err.msg()) }
}

pub fn rename(source string, dest string) ! {
    copy_then_remove(source, dest)!
}

pub fn replace(source string, dest string) ! {
    copy_then_remove(source, dest)!
}

// No chdir or processor-query API was included in the reference.
pub fn chdir(path string) ! {
    _ = path
    return pyrt.raise('NotImplementedError', 'os.chdir is absent from the supplied V reference')
}

pub fn cpu_count() ?int { return none }

fn walk_into(top string, mut rows []WalkEntry, visited []string) {
    if !os.is_dir(top) { return }
    canonical := os.real_path(top)
    if canonical in visited { return }
    mut current_visited := visited.clone()
    current_visited << canonical
    names := os.ls(top) or { return }
    mut dirs := []string{}
    mut files := []string{}
    for name in names {
        child := os.join_path(top, name)
        if os.is_dir(child) {
            dirs << name
        } else {
            files << name
        }
    }
    // os.walk itself guarantees no directory ordering; sorting gives tests
    // a deterministic result. Symlinked directories appear in dirnames but
    // are not recursed into when they resolve outside the lexical directory.
    dirs.sort()
    files.sort()
    rows << WalkEntry{dirpath: top, dirnames: dirs.clone(), filenames: files.clone()}
    for name in dirs {
        child := os.join_path(top, name)
        if os.real_path(child) != os.join_path(canonical, name) { continue }
        walk_into(child, mut rows, current_visited)
    }
}

pub fn walk_entries(top string) []WalkEntry {
    mut rows := []WalkEntry{}
    walk_into(top, mut rows, []string{})
    return rows
}

// Python os.walk yields (dirpath, dirnames, filenames) tuples. Here it returns
// an eager []pyrt.Value snapshot of those triples because the pinned V core
// has no lazy Python generator protocol.
pub fn walk(top string) []pyrt.Value {
    mut out := []pyrt.Value{}
    for row in walk_entries(top) {
        path := pyrt.Value(row.dirpath)
        dirs := pyrt.from_strings(row.dirnames)
        files := pyrt.from_strings(row.filenames)
        out << pyrt.Value(pyrt.new_tuple([path, dirs, files]))
    }
    return out
}
