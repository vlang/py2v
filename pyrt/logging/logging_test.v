module logging

import os
import pyrt

fn test_logging_hierarchy_and_lazy_arguments() { check_logging_hierarchy_and_lazy_arguments() or { panic(err.msg()) } }
fn check_logging_hierarchy_and_lazy_arguments() ! {
    reset_logging()
    defer { reset_logging() }
    root := get_logger('')
    sink := new_stream_handler('memory')!
    sink.set_formatter(new_formatter(fmt: '%(levelname)s %(name)s %(message)s'))
    root.add_handler(sink)
    parent := get_logger('pkg')
    parent.set_level(info_level)
    mut child := get_logger('pkg.child')
    child.info('job=%s value=%.2f', pyrt.Value('alpha'), pyrt.Value(f64(2.675)))
    child.debug('not formatted: %q', pyrt.Value(1))
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1)", 'buf.getvalue()') == 'INFO pkg.child job=alpha value=2.67\n'
    assert sink.getvalue() == 'INFO pkg.child job=alpha value=2.67\n'
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1)", 'child.getEffectiveLevel()') == 20
    assert child.get_effective_level() == info_level
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1)", 'child.isEnabledFor(logging.INFO)') == True
    assert child.is_enabled_for(info_level)
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1)", 'child.isEnabledFor(logging.DEBUG)') == False
    assert !child.is_enabled_for(debug_level)
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1)", 'child.hasHandlers()') == True
    assert child.has_handlers()
    same := get_logger('pkg.child')
    same.set_level(debug_level)
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1);logging.getLogger('pkg.child').setLevel(logging.DEBUG)", 'child.level') == 10
    assert child.level == debug_level
    child.disabled = true
    child.error_('blocked')
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1);child.disabled=True;child.error('blocked')", 'buf.getvalue()') == 'INFO pkg.child job=alpha value=2.67\n'
    assert sink.getvalue() == 'INFO pkg.child job=alpha value=2.67\n'
    child.disabled = false
    disable(error_level)
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1);logging.disable(logging.ERROR)", 'child.isEnabledFor(logging.ERROR)') == False
    assert !child.is_enabled_for(error_level)
    // python: logging_probe("buf=io.StringIO();h=logging.StreamHandler(buf);h.setFormatter(logging.Formatter('%(levelname)s %(name)s %(message)s'));root.addHandler(h);parent=logging.getLogger('pkg');parent.setLevel(logging.INFO);child=logging.getLogger('pkg.child');child.info('job=%s value=%.2f','alpha',2.675);child.debug('not formatted: %q',1);logging.disable(logging.ERROR)", 'child.isEnabledFor(logging.CRITICAL)') == True
    assert child.is_enabled_for(critical_level)
    disable(notset_level)
    late := get_logger('late.branch')
    // python: logging_probe("late=logging.getLogger('late.branch')", 'late.getEffectiveLevel()') == 30
    assert late.get_effective_level() == warning_level
    get_logger('late').set_level(debug_level)
    // python: logging_probe("late=logging.getLogger('late.branch');logging.getLogger('late').setLevel(logging.DEBUG)", 'late.getEffectiveLevel()') == 10
    assert late.get_effective_level() == debug_level
}
fn test_logging_handlers_and_propagation() { check_logging_handlers_and_propagation() or { panic(err.msg()) } }
fn check_logging_handlers_and_propagation() ! {
    reset_logging()
    defer { reset_logging() }
    root := get_logger('')
    root.set_level(critical_level)
    parent_sink := new_stream_handler('memory')!
    root.add_handler(parent_sink)
    mut child := get_logger('worker')
    child.set_level(debug_level)
    local_sink := new_stream_handler('memory')!
    local_sink.set_level(warning_level)
    child.add_handler(local_sink)
    child.add_handler(local_sink)
    child.info('parent despite root threshold')
    child.warning('both')
    // python: logging_probe("root.setLevel(logging.CRITICAL);a=io.StringIO();b=io.StringIO();ha=logging.StreamHandler(a);hb=logging.StreamHandler(b);hb.setLevel(logging.WARNING);root.addHandler(ha);child=logging.getLogger('worker');child.setLevel(logging.DEBUG);child.addHandler(hb);child.addHandler(hb);child.info('parent despite root threshold');child.warning('both')", 'a.getvalue()') == 'parent despite root threshold\nboth\n'
    assert parent_sink.getvalue() == 'parent despite root threshold\nboth\n'
    // python: logging_probe("root.setLevel(logging.CRITICAL);a=io.StringIO();b=io.StringIO();ha=logging.StreamHandler(a);hb=logging.StreamHandler(b);hb.setLevel(logging.WARNING);root.addHandler(ha);child=logging.getLogger('worker');child.setLevel(logging.DEBUG);child.addHandler(hb);child.addHandler(hb);child.info('parent despite root threshold');child.warning('both')", 'b.getvalue()') == 'both\n'
    assert local_sink.getvalue() == 'both\n'
    child.propagate = false
    child.error_('local')
    // python: logging_probe("root.setLevel(logging.CRITICAL);a=io.StringIO();b=io.StringIO();ha=logging.StreamHandler(a);hb=logging.StreamHandler(b);hb.setLevel(logging.WARNING);root.addHandler(ha);child=logging.getLogger('worker');child.setLevel(logging.DEBUG);child.addHandler(hb);child.addHandler(hb);child.info('parent despite root threshold');child.warning('both');child.propagate=False;child.error('local')", 'b.getvalue()') == 'both\nlocal\n'
    assert local_sink.getvalue() == 'both\nlocal\n'
    // python: logging_probe("root.setLevel(logging.CRITICAL);a=io.StringIO();b=io.StringIO();ha=logging.StreamHandler(a);hb=logging.StreamHandler(b);hb.setLevel(logging.WARNING);root.addHandler(ha);child=logging.getLogger('worker');child.setLevel(logging.DEBUG);child.addHandler(hb);child.addHandler(hb);child.info('parent despite root threshold');child.warning('both');child.propagate=False;child.error('local')", 'a.getvalue()') == 'parent despite root threshold\nboth\n'
    assert parent_sink.getvalue() == 'parent despite root threshold\nboth\n'
    child.remove_handler(local_sink)
    // python: logging_probe("root.setLevel(logging.CRITICAL);a=io.StringIO();b=io.StringIO();ha=logging.StreamHandler(a);hb=logging.StreamHandler(b);hb.setLevel(logging.WARNING);root.addHandler(ha);child=logging.getLogger('worker');child.setLevel(logging.DEBUG);child.addHandler(hb);child.addHandler(hb);child.info('parent despite root threshold');child.warning('both');child.propagate=False;child.removeHandler(hb)", 'child.hasHandlers()') == False
    assert !child.has_handlers()
    // python: logging_probe('', 'logging.getLevelName(0)') == 'NOTSET'
    assert get_level_name(0) == 'NOTSET'
    // python: logging_probe('', 'logging.getLevelName(10)') == 'DEBUG'
    assert get_level_name(10) == 'DEBUG'
    // python: logging_probe('', 'logging.getLevelName(20)') == 'INFO'
    assert get_level_name(20) == 'INFO'
    // python: logging_probe('', 'logging.getLevelName(30)') == 'WARNING'
    assert get_level_name(30) == 'WARNING'
    // python: logging_probe('', 'logging.getLevelName(40)') == 'ERROR'
    assert get_level_name(40) == 'ERROR'
    // python: logging_probe('', 'logging.getLevelName(50)') == 'CRITICAL'
    assert get_level_name(50) == 'CRITICAL'
    // python: logging_probe('', 'logging.getLevelName(17)') == 'Level 17'
    assert get_level_name(17) == 'Level 17'
}
fn test_logging_formatters() { check_logging_formatters() or { panic(err.msg()) } }
fn check_logging_formatters() ! {
    record := LogRecord{name: 'app', levelno: warning_level, message: '%s %03d', args: [pyrt.Value('job'), pyrt.Value(7)], filename: 'worker.py', pathname: '/tmp/worker.py', lineno: 12, func_name: 'main'}
    formatter := new_formatter(fmt: '%(levelname)s:%(name)s:%(filename)s:%(lineno)d:%(funcName)s:%(message)s')
    // python: logging_probe("record=logging.LogRecord('app',logging.WARNING,'/tmp/worker.py',12,'%s %03d',('job',7),None,func='main');formatter=logging.Formatter('%(levelname)s:%(name)s:%(filename)s:%(lineno)d:%(funcName)s:%(message)s')", 'record.getMessage()') == 'job 007'
    assert record.get_message()! == 'job 007'
    // python: logging_probe("record=logging.LogRecord('app',logging.WARNING,'/tmp/worker.py',12,'%s %03d',('job',7),None,func='main');formatter=logging.Formatter('%(levelname)s:%(name)s:%(filename)s:%(lineno)d:%(funcName)s:%(message)s')", 'formatter.format(record)') == 'WARNING:app:worker.py:12:main:job 007'
    assert formatter.format(record)! == 'WARNING:app:worker.py:12:main:job 007'
    handler := new_stream_handler('memory')!
    handler.set_formatter(formatter)
    // python: logging_probe("record=logging.LogRecord('app',logging.WARNING,'/tmp/worker.py',12,'%s %03d',('job',7),None,func='main');formatter=logging.Formatter('%(levelname)s:%(name)s:%(filename)s:%(lineno)d:%(funcName)s:%(message)s')", 'formatter.format(record)') == 'WARNING:app:worker.py:12:main:job 007'
    assert handler.format(record)! == 'WARNING:app:worker.py:12:main:job 007'
    mapping := pyrt.from_map(map[string]pyrt.Value{'name': pyrt.Value('Ada'), 'n': pyrt.Value(3)})
    mapped := LogRecord{message: '%(name)s:%(n)d', args: [mapping]}
    // python: logging_probe("r=logging.LogRecord('app',20,'',0,'%(name)s:%(n)d',({'name':'Ada','n':3},),None)", 'r.getMessage()') == 'Ada:3'
    assert mapped.get_message()! == 'Ada:3'
    literal := LogRecord{message: 'literal 100%'}
    // python: logging_probe("r=logging.LogRecord('app',20,'',0,'literal 100%',(),None)", 'r.getMessage()') == 'literal 100%'
    assert literal.get_message()! == 'literal 100%'
    clock := LogRecord{message: 'x', created: 1704067200.125}
    dated := new_formatter(fmt: '%(asctime)s %(message)s', datefmt: 'fixed %%')
    // python: logging_probe("r=logging.LogRecord('app',20,'',0,'x',(),None);r.created=1704067200.125;r.msecs=125", "logging.Formatter('%(asctime)s %(message)s',datefmt='fixed %%').format(r)") == 'fixed % x'
    assert dated.format(clock)! == 'fixed % x'
    millis := new_formatter(fmt: '%(created).3f %(msecs)03d')
    // python: logging_probe("r=logging.LogRecord('app',20,'',0,'x',(),None);r.created=1704067200.125;r.msecs=125", "logging.Formatter('%(created).3f %(msecs)03d').format(r)") == '1704067200.125 125'
    assert millis.format(clock)! == '1704067200.125 125'
}
fn test_logging_root_calls_and_keywords() { check_logging_root_calls_and_keywords() or { panic(err.msg()) } }
fn check_logging_root_calls_and_keywords() ! {
    reset_logging()
    defer { reset_logging() }
    basic_config(level: debug_level, format: '%(levelname)s:%(message)s', stream: 'memory')!
    root := get_logger('')
    sink := root.handlers[0]
    debug('debug %s', pyrt.Value('d'))
    info('info %d', pyrt.Value(2))
    warning('warn')
    error_('error')
    critical('critical')
    log(25, 'custom')
    exception('outside exception')
    // python: logging_probe("buf=io.StringIO();logging.basicConfig(level=logging.DEBUG,format='%(levelname)s:%(message)s',stream=buf);logging.debug('debug %s','d');logging.info('info %d',2);logging.warning('warn');logging.error('error');logging.critical('critical');logging.log(25,'custom');logging.exception('outside exception')", 'buf.getvalue()') == 'DEBUG:debug d\nINFO:info 2\nWARNING:warn\nERROR:error\nCRITICAL:critical\nLevel 25:custom\nERROR:outside exception\nNoneType: None\n'
    assert sink.getvalue() == 'DEBUG:debug d\nINFO:info 2\nWARNING:warn\nERROR:error\nCRITICAL:critical\nLevel 25:custom\nERROR:outside exception\nNoneType: None\n'
    basic_config(level: critical_level, stream: 'memory')!
    // python: logging_probe("buf=io.StringIO();logging.basicConfig(level=logging.DEBUG,format='%(levelname)s:%(message)s',stream=buf);logging.debug('debug %s','d');logging.info('info %d',2);logging.warning('warn');logging.error('error');logging.critical('critical');logging.log(25,'custom');logging.exception('outside exception');logging.basicConfig(level=logging.CRITICAL,stream=io.StringIO())", 'root.level') == 10
    assert root.level == debug_level
    basic_config(level: debug_level, stream: 'memory', format: '%(message)s', force: true)!
    keywords := root.handlers[0]
    info_with('without', []pyrt.Value{}, exc_info: false)
    error_with('with', []pyrt.Value{}, exc_info: true)
    exception_with('suppressed', []pyrt.Value{}, exc_info: false)
    // python: logging_probe("buf=io.StringIO();logging.basicConfig(level=logging.DEBUG,stream=buf,format='%(message)s',force=True);logging.info('without',exc_info=False);logging.error('with',exc_info=True);logging.exception('suppressed',exc_info=False)", 'buf.getvalue()') == 'without\nwith\nNoneType: None\nsuppressed\n'
    assert keywords.getvalue() == 'without\nwith\nNoneType: None\nsuppressed\n'
    local := get_logger('local')
    local.debug_with('d', []pyrt.Value{}, LogOptions{})
    local.info_with('i', []pyrt.Value{}, LogOptions{})
    local.warning_with('w', []pyrt.Value{}, LogOptions{})
    local.error_with('e', []pyrt.Value{}, exc_info: false)
    local.critical_with('c', []pyrt.Value{}, LogOptions{})
    local.exception_with('x', []pyrt.Value{}, exc_info: false)
    local.log_with(21, 'l', []pyrt.Value{}, LogOptions{})
    // python: logging_probe("buf=io.StringIO();logging.basicConfig(level=logging.DEBUG,stream=buf,format='%(message)s',force=True);logging.info('without',exc_info=False);logging.error('with',exc_info=True);logging.exception('suppressed',exc_info=False);local=logging.getLogger('local');local.debug('d');local.info('i');local.warning('w');local.error('e',exc_info=False);local.critical('c');local.exception('x',exc_info=False);local.log(21,'l')", 'buf.getvalue()') == 'without\nwith\nNoneType: None\nsuppressed\nd\ni\nw\ne\nc\nx\nl\n'
    assert keywords.getvalue() == 'without\nwith\nNoneType: None\nsuppressed\nd\ni\nw\ne\nc\nx\nl\n'
    debug_with('md', []pyrt.Value{}, LogOptions{})
    warning_with('mw', []pyrt.Value{}, LogOptions{})
    critical_with('mc', []pyrt.Value{}, LogOptions{})
    log_with(21, 'ml', []pyrt.Value{}, LogOptions{})
    // python: logging_probe("buf=io.StringIO();logging.basicConfig(level=logging.DEBUG,stream=buf,format='%(message)s',force=True);logging.info('without',exc_info=False);logging.error('with',exc_info=True);logging.exception('suppressed',exc_info=False);local=logging.getLogger('local');local.debug('d');local.info('i');local.warning('w');local.error('e',exc_info=False);local.critical('c');local.exception('x',exc_info=False);local.log(21,'l');logging.debug('md');logging.warning('mw');logging.critical('mc');logging.log(21,'ml')", 'buf.getvalue()') == 'without\nwith\nNoneType: None\nsuppressed\nd\ni\nw\ne\nc\nx\nl\nmd\nmw\nmc\nml\n'
    assert keywords.getvalue() == 'without\nwith\nNoneType: None\nsuppressed\nd\ni\nw\ne\nc\nx\nl\nmd\nmw\nmc\nml\n'
}
fn test_logging_files() { check_logging_files() or { panic(err.msg()) } }
fn check_logging_files() ! {
    reset_logging()
    defer { reset_logging() }
    directory := os.join_path(os.vtmp_dir(), 'pyrt_round5_logging_tests')
    os.mkdir_all(directory)!
    defer { os.rmdir_all(directory) or {} }
    path := os.join_path(directory, 'run.log')
    os.write_file(path, 'prefix\n')!
    handler := new_file_handler(path, mode: 'a')!
    handler.set_formatter(new_formatter(fmt: '%(message)s'))
    handler.emit(LogRecord{message: 'one'})!
    handler.emit(LogRecord{message: 'two'})!
    handler.close()
    // python: logging_probe("path.write_text('prefix\\n');h=logging.FileHandler(path,mode='a');h.setFormatter(logging.Formatter('%(message)s'));h.emit(logging.LogRecord('app',20,'',0,'one',(),None));h.emit(logging.LogRecord('app',20,'',0,'two',(),None));h.close()", 'path.read_text()') == 'prefix\none\ntwo\n'
    assert os.read_file(path)! == 'prefix\none\ntwo\n'
    os.rm(path)!
    delayed := new_file_handler(path, mode: 'w', delay: true)!
    // python: logging_probe("h=logging.FileHandler(path,mode='w',delay=True)", 'path.exists()') == False
    assert !os.exists(path)
    delayed.emit(LogRecord{message: 'created'})!
    delayed.close()
    // python: logging_probe("h=logging.FileHandler(path,mode='w',delay=True);h.emit(logging.LogRecord('app',20,'',0,'created',(),None));h.close()", 'path.read_text()') == 'created\n'
    assert os.read_file(path)! == 'created\n'
    basic_config(level: info_level, filename: path, filemode: 'w', format: '%(name)s:%(message)s')!
    get_logger('file.worker').info('saved')
    shutdown()
    // python: logging_probe("logging.basicConfig(level=logging.INFO,filename=path,filemode='w',format='%(name)s:%(message)s');logging.getLogger('file.worker').info('saved');logging.shutdown()", 'path.read_text()') == 'file.worker:saved\n'
    assert os.read_file(path)! == 'file.worker:saved\n'
}
fn logging_error_text(which int) string {
    if which == 0 {
        basic_config(filename: 'unused.log', stream: 'stderr', force: true) or { return err.msg() }
    }
    if which == 1 {
        r := LogRecord{message: '%d', args: [pyrt.Value('x')]}
        r.get_message() or { return err.msg() }
    }
    if which == 2 {
        f := new_formatter(fmt: '%(absent)s')
        f.format(LogRecord{message: 'x'}) or { return err.msg() }
    }
    return '<no error>'
}
fn test_logging_errors_and_exception_summary() {
    reset_logging()
    defer { reset_logging() }
    // python: logging_probe("try:\n logging.basicConfig(filename='unused.log',stream=io.StringIO(),force=True)\nexcept Exception as e:\n result=str(e)", 'result') == "'stream' and 'filename' should not be specified together"
    assert logging_error_text(0) == "'stream' and 'filename' should not be specified together"
    // python: logging_probe("try:\n logging.LogRecord('app',20,'',0,'%d',('x',),None).getMessage()\nexcept Exception as e:\n result=str(e)", 'result') == '%d format: a real number is required, not str'
    assert logging_error_text(1) == '%d format: a real number is required, not str'
    // python: logging_probe("try:\n logging.Formatter('%(absent)s').format(logging.LogRecord('app',20,'',0,'x',(),None))\nexcept Exception as e:\n result=str(e)", 'result') == "Formatting field not found in record: 'absent'"
    assert logging_error_text(2) == "Formatting field not found in record: 'absent'"
    active := pyrt.raise('ValueError', 'boom')
    text := exception_text(LogOptions{exc_info: true, exception_value: active}, false)
    // python: logging_probe("try:\n raise ValueError('boom')\nexcept Exception:\n import sys\n result=logging.Formatter().formatException(sys.exc_info()).splitlines()[-1]", 'result') == 'ValueError: boom'
    assert text == 'ValueError: boom'
}

fn test_logging_warn_aliases() {
    reset_logging()
    defer { reset_logging() }
    basic_config(level: warning_level, format: '%(message)s', stream: 'memory') or { panic(err.msg()) }
    sink := get_logger('').handlers[0]
    warn('root %s', pyrt.Value('warn'))
    worker := get_logger('worker')
    worker.warn('child %d', pyrt.Value(2))
    worker.warn_with('keyword %s', [pyrt.Value('ok')], LogOptions{})
    warn_with('root keyword', []pyrt.Value{}, LogOptions{})
    // python: logging_probe("buf=io.StringIO();logging.basicConfig(level=logging.WARNING,format='%(message)s',stream=buf);logging.warn('root %s','warn');logging.getLogger('worker').warn('child %d',2);logging.getLogger('worker').warning('keyword %s','ok');logging.warning('root keyword')", 'buf.getvalue()') == 'root warn\nchild 2\nkeyword ok\nroot keyword\n'
    assert sink.getvalue() == 'root warn\nchild 2\nkeyword ok\nroot keyword\n'
}
