module logging

import os
import time
import pyrt

// Function names occupy V's value namespace, so Python DEBUG/INFO/etc. use
// *_level constants rather than colliding with debug()/info()/warning().
pub const notset_level = 0
pub const debug_level = 10
pub const info_level = 20
pub const warning_level = 30
pub const error_level = 40
pub const critical_level = 50

@[params]
pub struct BasicConfigOptions {
pub:
    level ?int
    format string = '%(levelname)s:%(name)s:%(message)s'
    datefmt string
    stream string
    filename string
    filemode string = 'a'
    force bool
}

@[params]
pub struct FormatterOptions {
pub:
    fmt string = '%(message)s'
    datefmt string
}

@[params]
pub struct FileOptions {
pub:
    mode string = 'a'
    delay bool
}

@[params]
pub struct LogOptions {
pub:
    exc_info ?bool
    exception_value IError = none
    stack_info bool
    filename string = '<unknown>'
    pathname string = '<unknown>'
    lineno int
    func_name string = '<unknown>'
}

pub struct Formatter {
pub:
    fmt string = '%(message)s'
    datefmt string
}

pub struct LogRecord {
pub:
    name string
    levelno int
    message string
    args []pyrt.Value
    created f64
    relative_created f64
    filename string = '<unknown>'
    pathname string = '<unknown>'
    lineno int
    func_name string = '<unknown>'
    exception_text string
    stack_text string
}

struct FileSlot {
mut:
    file os.File
}

// StreamHandler and FileHandler share a concrete V representation. Python
// class names remain distinct in api.json, both with v_type logging.Handler.
pub struct Handler {
    identity i64
    stream string
    filename string
    mode string
pub mut:
    level int
    formatter Formatter
mut:
    files []&FileSlot
    closed bool
    memory string
}

pub struct Logger {
pub:
    name string
pub mut:
    level int
    disabled bool
    propagate bool = true
mut:
    handlers []&Handler
}

struct LogRegistry {
mut:
    loggers map[string]&Logger
    disable_level int
    started f64
}

// Like the other runtime registries, this is process-local and UNSYNCHRONIZED.
const log_registry = &LogRegistry{loggers: map[string]&Logger{}}

fn clock_seconds() f64 { return f64(time.now().unix_micro()) / 1000000.0 }

pub fn get_logger(name string) &Logger {
    actual := if name == '' { 'root' } else { name }
    mut registry := unsafe { log_registry }
    if existing := registry.loggers[actual] { return existing }
    if registry.started == 0.0 { registry.started = clock_seconds() }
    logger := &Logger{name: actual, level: if actual == 'root' { warning_level } else { notset_level },
        propagate: true}
    registry.loggers[actual] = logger
    return logger
}

fn parent_logger(name string) &Logger {
    mut i := name.len - 1
    for i >= 0 {
        if name[i] == 46 {
            prefix := name[0 .. i]
            if ancestor := log_registry.loggers[prefix] { return ancestor }
        }
        i = i - 1
    }
    return get_logger('')
}

pub fn get_level_name(level int) string {
    return match level {
        0 { 'NOTSET' } 10 { 'DEBUG' } 20 { 'INFO' } 30 { 'WARNING' }
        40 { 'ERROR' } 50 { 'CRITICAL' } else { 'Level ${level}' }
    }
}

pub fn (l &Logger) set_level(level int) { unsafe { l.level = level } }
pub fn (l &Logger) get_effective_level() int {
    mut node := l
    for {
        if node.level != 0 || node.name == 'root' { return node.level }
        node = parent_logger(node.name)
    }
    return notset_level
}
pub fn (l &Logger) is_enabled_for(level int) bool {
    return !l.disabled && level > log_registry.disable_level && level >= l.get_effective_level()
}
pub fn disable(level int) {
    mut registry := unsafe { log_registry }
    registry.disable_level = level
}

pub fn new_formatter(opts FormatterOptions) Formatter {
    return Formatter{fmt: if opts.fmt == '' { '%(message)s' } else { opts.fmt }, datefmt: opts.datefmt}
}

pub fn (r LogRecord) get_message() !string {
    if r.args.len == 0 { return r.message }
    mut operand := pyrt.Value(pyrt.new_tuple(r.args))
    if r.args.len == 1 {
        only := r.args[0]
        if only is &pyrt.Dict { if only.keys.len > 0 { operand = only } }
    }
    return pyrt.percent_format(r.message, operand)!
}

fn (f Formatter) format_time(record LogRecord) string {
    micros := i64(record.created * 1000000.0)
    stamp := time.unix_micro(micros).local()
    if f.datefmt != '' { return stamp.strftime(f.datefmt) }
    mut milliseconds := int((micros / 1000) % 1000)
    if milliseconds < 0 { milliseconds = milliseconds + 1000 }
    mut digits := milliseconds.str()
    for digits.len < 3 { digits = '0' + digits }
    return stamp.strftime('%Y-%m-%d %H:%M:%S') + ',' + digits
}

pub fn (f Formatter) format(record LogRecord) !string {
    message := record.get_message()!
    mut fields := map[string]pyrt.Value{}
    fields['message'] = pyrt.Value(message)
    fields['name'] = pyrt.Value(record.name)
    fields['levelname'] = pyrt.Value(get_level_name(record.levelno))
    fields['levelno'] = pyrt.Value(i64(record.levelno))
    fields['filename'] = pyrt.Value(record.filename)
    fields['pathname'] = pyrt.Value(record.pathname)
    fields['lineno'] = pyrt.Value(i64(record.lineno))
    fields['funcName'] = pyrt.Value(record.func_name)
    fields['module'] = pyrt.Value('<unknown>')
    fields['created'] = pyrt.Value(record.created)
    fields['relativeCreated'] = pyrt.Value(record.relative_created)
    micros := i64(record.created * 1000000.0)
    mut milliseconds := (micros / 1000) % 1000
    if milliseconds < 0 { milliseconds = milliseconds + 1000 }
    fields['msecs'] = pyrt.Value(f64(milliseconds))
    fields['asctime'] = pyrt.Value(f.format_time(record))
    fields['thread'] = pyrt.Value(i64(0))
    fields['threadName'] = pyrt.Value('MainThread')
    fields['process'] = pyrt.Value(i64(0))
    fields['processName'] = pyrt.Value('MainProcess')
    fields['taskName'] = pyrt.none_
    mut rendered := pyrt.percent_format(f.fmt, pyrt.from_map(fields)) or {
        if missing := pyrt.caught(err, 'KeyError') {
            return pyrt.raise('ValueError', 'Formatting field not found in record: ' + missing.msg())
        }
        return err
    }
    if record.exception_text != '' {
        if rendered.len > 0 && rendered[rendered.len - 1] != 10 { rendered = rendered + '\n' }
        rendered = rendered + record.exception_text
    }
    if record.stack_text != '' {
        if rendered.len > 0 && rendered[rendered.len - 1] != 10 { rendered = rendered + '\n' }
        rendered = rendered + record.stack_text
    }
    return rendered
}

pub fn new_stream_handler(stream string) !&Handler {
    target := if stream == '' { 'stderr' } else { stream }
    if target !in ['stdout', 'stderr', 'memory'] {
        return pyrt.raise('NotImplementedError', 'logging streams must be stdout, stderr, or the runtime memory sink')
    }
    return &Handler{identity: pyrt.identity_token(), stream: target}
}

fn (h &Handler) open_file() ! {
    if h.files.len > 0 { return }
    // No append-open API appears in the supplied reference. Preserve existing
    // text before opening with create, then retain one writer for later emits.
    // This initial read/truncate/rewrite is NOT atomic or multi-process safe.
    mut previous := ''
    if h.mode == 'a' && os.exists(h.filename) {
        previous = os.read_file(h.filename) or { return pyrt.raise('OSError', err.msg()) }
    }
    mut file := os.create(h.filename) or { return pyrt.raise('OSError', err.msg()) }
    if previous != '' {
        count := file.write_string(previous) or { file.close(); return pyrt.raise('OSError', err.msg()) }
        if count != previous.len { file.close(); return pyrt.raise('OSError', 'short write while opening log file') }
    }
    unsafe { h.files << &FileSlot{file: file} }
}

pub fn new_file_handler(filename string, opts FileOptions) !&Handler {
    if opts.mode != 'a' && opts.mode != 'w' { return pyrt.raise('ValueError', "invalid mode: '${opts.mode}'") }
    handler := &Handler{identity: pyrt.identity_token(), stream: 'file', filename: filename, mode: opts.mode}
    if !opts.delay { handler.open_file()! }
    return handler
}

pub fn (h &Handler) set_level(level int) { unsafe { h.level = level } }
pub fn (h &Handler) set_formatter(formatter Formatter) { unsafe { h.formatter = formatter } }
pub fn (h &Handler) format(record LogRecord) !string { return h.formatter.format(record)! }
pub fn (h &Handler) getvalue() string { return h.memory }

pub fn (h &Handler) emit(record LogRecord) ! {
    if h.closed { return }
    rendered := h.format(record)!
    if h.stream == 'stderr' { eprintln(rendered); return }
    if h.stream == 'stdout' { print(rendered + '\n'); return }
    if h.stream == 'memory' { unsafe { h.memory = h.memory + rendered + '\n' }; return }
    h.open_file()!
    mut slot := h.files[0]
    text := rendered + '\n'
    written := slot.file.write_string(text) or { return pyrt.raise('OSError', err.msg()) }
    if written != text.len { return pyrt.raise('OSError', 'short write to log file') }
}

pub fn (h &Handler) close() {
    if h.closed { return }
    for entry in h.files {
        mut slot := entry
        slot.file.close()
    }
    unsafe { h.closed = true; h.files = []&FileSlot{} }
}

pub fn (l &Logger) add_handler(handler &Handler) {
    for existing in l.handlers { if existing.identity == handler.identity { return } }
    unsafe { l.handlers << handler }
}
pub fn (l &Logger) remove_handler(handler &Handler) {
    mut kept := []&Handler{}
    for existing in l.handlers { if existing.identity != handler.identity { kept << existing } }
    unsafe { l.handlers = kept.clone() }
}
pub fn (l &Logger) has_handlers() bool {
    mut node := l
    for {
        if node.handlers.len > 0 { return true }
        if node.name == 'root' || !node.propagate { return false }
        node = parent_logger(node.name)
    }
    return false
}

pub fn basic_config(opts BasicConfigOptions) ! {
    root := get_logger('')
    if opts.force {
        for handler in root.handlers { handler.close() }
        unsafe { root.handlers = []&Handler{} }
    }
    if root.handlers.len > 0 { return }
    if opts.filename != '' && opts.stream != '' {
        return pyrt.raise('ValueError', "'stream' and 'filename' should not be specified together")
    }
    handler := if opts.filename != '' { new_file_handler(opts.filename, mode: opts.filemode)! } else { new_stream_handler(opts.stream)! }
    handler.set_formatter(new_formatter(fmt: opts.format, datefmt: opts.datefmt))
    root.add_handler(handler)
    if configured_level := opts.level { root.set_level(configured_level) }
}

fn exception_text(opts LogOptions, default_exc bool) string {
    enabled := opts.exc_info or { default_exc }
    if !enabled { return '' }
    active := opts.exception_value
    if active is pyrt.PyError {
        return active.class_name + ': ' + active.msg()
    }
    if opts.exception_value != none { return 'Exception: ' + opts.exception_value.msg() }
    return 'NoneType: None'
}

fn report_logging_error(err IError, record LogRecord) {
    // CPython handleError reports and suppresses emission failures. We do the
    // same, without a fabricated Python traceback or source stack.
    eprintln('--- Logging error ---')
    eprintln(err.msg())
    eprintln('Message: ' + pyrt.repr(pyrt.Value(record.message)))
    eprintln('Arguments: ' + pyrt.repr(pyrt.Value(pyrt.new_tuple(record.args))))
}

fn (l &Logger) dispatch(level int, message string, args []pyrt.Value, opts LogOptions, default_exc bool) {
    if !l.is_enabled_for(level) { return }
    created := clock_seconds()
    record := LogRecord{name: l.name, levelno: level, message: message, args: args.clone(), created: created,
        relative_created: (created - log_registry.started) * 1000.0, filename: opts.filename, pathname: opts.pathname,
        lineno: opts.lineno, func_name: opts.func_name, exception_text: exception_text(opts, default_exc),
        stack_text: if opts.stack_info { 'Stack (most recent call last):\n  <source stack unavailable>' } else { '' }}
    mut found := 0
    mut node := l
    for {
        for handler in node.handlers {
            found = found + 1
            if level >= handler.level { handler.emit(record) or { report_logging_error(err, record) } }
        }
        if node.name == 'root' || !node.propagate { break }
        node = parent_logger(node.name)
    }
    if found == 0 && level >= warning_level {
        fallback := new_stream_handler('stderr') or { return }
        fallback.emit(record) or { report_logging_error(err, record) }
    }
}

pub fn (l &Logger) log(level int, message string, args ...pyrt.Value) { l.dispatch(level, message, args, LogOptions{}, false) }
pub fn (l &Logger) debug(message string, args ...pyrt.Value) { l.log(debug_level, message, ...args) }
pub fn (l &Logger) info(message string, args ...pyrt.Value) { l.log(info_level, message, ...args) }
pub fn (l &Logger) warning(message string, args ...pyrt.Value) { l.log(warning_level, message, ...args) }
// Deprecated Python spelling. Warnings are not emitted by this alias;
// it preserves logging output and routing only.
pub fn (l &Logger) warn(message string, args ...pyrt.Value) { l.warning(message, ...args) }
pub fn (l &Logger) error_(message string, args ...pyrt.Value) { l.log(error_level, message, ...args) }
pub fn (l &Logger) critical(message string, args ...pyrt.Value) { l.log(critical_level, message, ...args) }
pub fn (l &Logger) exception(message string, args ...pyrt.Value) { l.dispatch(error_level, message, args, LogOptions{}, true) }
pub fn (l &Logger) log_with(level int, message string, args []pyrt.Value, opts LogOptions) { l.dispatch(level, message, args, opts, false) }
pub fn (l &Logger) debug_with(message string, args []pyrt.Value, opts LogOptions) { l.log_with(debug_level, message, args, opts) }
pub fn (l &Logger) info_with(message string, args []pyrt.Value, opts LogOptions) { l.log_with(info_level, message, args, opts) }
pub fn (l &Logger) warning_with(message string, args []pyrt.Value, opts LogOptions) { l.log_with(warning_level, message, args, opts) }
pub fn (l &Logger) warn_with(message string, args []pyrt.Value, opts LogOptions) { l.warning_with(message, args, opts) }
pub fn (l &Logger) error_with(message string, args []pyrt.Value, opts LogOptions) { l.log_with(error_level, message, args, opts) }
pub fn (l &Logger) critical_with(message string, args []pyrt.Value, opts LogOptions) { l.log_with(critical_level, message, args, opts) }
pub fn (l &Logger) exception_with(message string, args []pyrt.Value, opts LogOptions) { l.dispatch(error_level, message, args, opts, true) }

fn root_logger() &Logger {
    logger := get_logger('')
    if logger.handlers.len == 0 { basic_config(BasicConfigOptions{}) or { eprintln(err.msg()) } }
    return logger
}
pub fn log(level int, message string, args ...pyrt.Value) { root_logger().log(level, message, ...args) }
pub fn debug(message string, args ...pyrt.Value) { root_logger().debug(message, ...args) }
pub fn info(message string, args ...pyrt.Value) { root_logger().info(message, ...args) }
pub fn warning(message string, args ...pyrt.Value) { root_logger().warning(message, ...args) }
pub fn warn(message string, args ...pyrt.Value) { root_logger().warn(message, ...args) }
pub fn error_(message string, args ...pyrt.Value) { root_logger().error_(message, ...args) }
pub fn critical(message string, args ...pyrt.Value) { root_logger().critical(message, ...args) }
pub fn exception(message string, args ...pyrt.Value) { root_logger().exception(message, ...args) }
pub fn log_with(level int, message string, args []pyrt.Value, opts LogOptions) { root_logger().log_with(level, message, args, opts) }
pub fn debug_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().debug_with(message, args, opts) }
pub fn info_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().info_with(message, args, opts) }
pub fn warning_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().warning_with(message, args, opts) }
pub fn warn_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().warn_with(message, args, opts) }
pub fn error_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().error_with(message, args, opts) }
pub fn critical_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().critical_with(message, args, opts) }
pub fn exception_with(message string, args []pyrt.Value, opts LogOptions) { root_logger().exception_with(message, args, opts) }

pub fn shutdown() {
    for _, logger in log_registry.loggers { for handler in logger.handlers { handler.close() } }
}

// Test/embedding helper, NOT a Python logging API. Existing logger handles
// belong to the old registry and should not be used after this call.
pub fn reset_logging() {
    shutdown()
    mut registry := unsafe { log_registry }
    registry.loggers = map[string]&Logger{}
    registry.disable_level = 0
    registry.started = 0.0
}
