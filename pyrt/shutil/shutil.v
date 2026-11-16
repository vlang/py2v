module shutil

import os
import pyrt

pub fn rmtree(path string) ! {
    if !os.exists(path) {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${path}'")
    }
    if !os.is_dir(path) {
        return pyrt.raise('NotADirectoryError', "[Errno 20] Not a directory: '${path}'")
    }
    os.rmdir_all(path) or { return pyrt.raise('OSError', err.msg()) }
}

pub fn which(command string) ?string {
    path := os.find_abs_path_of_executable(command) or { return none }
    return path
}

pub fn copyfile(source string, dest string) !string {
    if !os.exists(source) {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${source}'")
    }
    if os.abs_path(source) == os.abs_path(dest) {
        pyrt.register_exception('shutil.Error', ['OSError'])
        pyrt.register_exception('shutil.SameFileError', ['shutil.Error'])
        return pyrt.raise('shutil.SameFileError', "'${source}' and '${dest}' are the same file")
    }
    if os.is_dir(source) { return pyrt.raise('IsADirectoryError', "[Errno 21] Is a directory: '${source}'") }
    os.cp(source, dest, os.CopyParams{}) or { return pyrt.raise('OSError', err.msg()) }
    return dest
}

pub fn copy(source string, dest string) !string {
    destination := if os.is_dir(dest) { os.join_path(dest, os.base(source)) } else { dest }
    return copyfile(source, destination)!
}

// Copy metadata is not exposed in the supplied os API: copy2 == copy here.
pub fn copy2(source string, dest string) !string { return copy(source, dest)! }

pub fn move(source string, dest string) !string {
    if !os.exists(source) {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${source}'")
    }
    destination := if os.is_dir(dest) { os.join_path(dest, os.base(source)) } else { dest }
    os.mv(source, destination, os.MvParams{}) or { return pyrt.raise('OSError', err.msg()) }
    return destination
}

@[params]
pub struct CopytreeOptions {
pub:
    dirs_exist_ok bool
}

pub fn copytree(source string, dest string, opts CopytreeOptions) !string {
    if !os.is_dir(source) {
        return pyrt.raise('NotADirectoryError', "[Errno 20] Not a directory: '${source}'")
    }
    if os.exists(dest) && !opts.dirs_exist_ok {
        return pyrt.raise('FileExistsError', "[Errno 17] File exists: '${dest}'")
    }
    os.cp_all(source, dest, opts.dirs_exist_ok) or { return pyrt.raise('OSError', err.msg()) }
    return dest
}
