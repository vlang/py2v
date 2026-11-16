module tempfile

import os
import crypto.rand
import encoding.hex
import pyrt

@[params]
pub struct TempOptions {
pub:
    prefix string = 'tmp'
    suffix string
    dir string
}

pub fn gettempdir() string { return os.temp_dir() }

fn candidate(opts TempOptions) !string {
    randomness := rand.bytes(16)!
    suffix := hex.encode(randomness, hex.EncodeParams{})
    root := if opts.dir == '' { gettempdir() } else { opts.dir }
    return os.join_path(root, opts.prefix + suffix + opts.suffix)
}

pub fn mkdtemp(opts TempOptions) !string {
    for _ in 0 .. 20 {
        path := candidate(opts)!
        if os.exists(path) { continue }
        os.mkdir(path, os.MkdirParams{}) or { return pyrt.raise('OSError', err.msg()) }
        return path
    }
    return pyrt.raise('FileExistsError', 'No usable temporary directory name found')
}

pub struct TemporaryDirectory {
pub:
    name string
mut:
    cleaned bool
}

pub fn new_temporary_directory(opts TempOptions) !&TemporaryDirectory {
    return &TemporaryDirectory{name: mkdtemp(opts)!}
}

pub fn (t &TemporaryDirectory) cleanup() ! {
    if t.cleaned { return }
    if os.exists(t.name) { os.rmdir_all(t.name) or { return pyrt.raise('OSError', err.msg()) } }
    unsafe { t.cleaned = true }
}

// A V os.File is returned instead of Python's raw integer fd. os.create
// cannot offer O_EXCL in the supplied API: this has a TOCTOU race.
pub fn mkstemp(opts TempOptions) !(os.File, string) {
    for _ in 0 .. 20 {
        path := candidate(opts)!
        if os.exists(path) { continue }
        handle := os.create(path) or { return pyrt.raise('OSError', err.msg()) }
        return handle, path
    }
    return pyrt.raise('FileExistsError', 'No usable temporary filename found')
}
