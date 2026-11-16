module pyrt

// Runtime state is explicitly process-local and UNSYNCHRONIZED. Initialize
// exception classes before starting parallel translated code. The reference
// supplies no synchronization API. Pointer indirection permits the same unsafe
// mutation of a reference-backed object used by value.v in the supplied sample.
struct RuntimeState {
mut:
	registered    map[string][]string
	next_identity i64 = 1
}

const runtime_state = &RuntimeState{registered: map[string][]string{}}

// Tokens identify runtime objects, not memory addresses or CPython id() values.
pub fn identity_token() i64 {
	mut state := unsafe { runtime_state }
	out := state.next_identity
	state.next_identity = out + 1
	return out
}

// Direct bases, rather than a flattened list, allow registration below any
// builtin. Aliases such as IOError are normalized by canonical_exception_name.
const builtin_bases = {
	'BaseException':             []string{}
	'BaseExceptionGroup':        ['BaseException']
	'Exception':                 ['BaseException']
	'ExceptionGroup':            ['Exception', 'BaseExceptionGroup']
	'GeneratorExit':             ['BaseException']
	'KeyboardInterrupt':         ['BaseException']
	'SystemExit':                ['BaseException']
	'ArithmeticError':           ['Exception']
	'FloatingPointError':        ['ArithmeticError']
	'OverflowError':             ['ArithmeticError']
	'ZeroDivisionError':         ['ArithmeticError']
	'AssertionError':            ['Exception']
	'AttributeError':            ['Exception']
	'BufferError':               ['Exception']
	'EOFError':                  ['Exception']
	'ImportError':               ['Exception']
	'ModuleNotFoundError':        ['ImportError']
	'LookupError':               ['Exception']
	'IndexError':                ['LookupError']
	'KeyError':                  ['LookupError']
	'MemoryError':               ['Exception']
	'NameError':                 ['Exception']
	'UnboundLocalError':          ['NameError']
	'OSError':                   ['Exception']
	'BlockingIOError':           ['OSError']
	'ChildProcessError':          ['OSError']
	'ConnectionError':           ['OSError']
	'BrokenPipeError':            ['ConnectionError']
	'ConnectionAbortedError':     ['ConnectionError']
	'ConnectionRefusedError':     ['ConnectionError']
	'ConnectionResetError':       ['ConnectionError']
	'FileExistsError':            ['OSError']
	'FileNotFoundError':          ['OSError']
	'InterruptedError':           ['OSError']
	'IsADirectoryError':          ['OSError']
	'NotADirectoryError':         ['OSError']
	'PermissionError':            ['OSError']
	'ProcessLookupError':         ['OSError']
	'TimeoutError':               ['OSError']
	'ReferenceError':             ['Exception']
	'RuntimeError':               ['Exception']
	'NotImplementedError':        ['RuntimeError']
	'RecursionError':             ['RuntimeError']
	'PythonFinalizationError':    ['RuntimeError']
	'StopAsyncIteration':         ['Exception']
	'StopIteration':              ['Exception']
	'SyntaxError':                ['Exception']
	'IndentationError':           ['SyntaxError']
	'TabError':                   ['IndentationError']
	'SystemError':                ['Exception']
	'TypeError':                  ['Exception']
	'ValueError':                 ['Exception']
	'UnicodeError':               ['ValueError']
	'UnicodeDecodeError':         ['UnicodeError']
	'UnicodeEncodeError':         ['UnicodeError']
	'UnicodeTranslateError':      ['UnicodeError']
	'Warning':                   ['Exception']
	'BytesWarning':              ['Warning']
	'DeprecationWarning':        ['Warning']
	'EncodingWarning':           ['Warning']
	'FutureWarning':             ['Warning']
	'ImportWarning':             ['Warning']
	'PendingDeprecationWarning': ['Warning']
	'ResourceWarning':           ['Warning']
	'RuntimeWarning':            ['Warning']
	'SyntaxWarning':             ['Warning']
	'UnicodeWarning':            ['Warning']
	'UserWarning':               ['Warning']
}

fn canonical_exception_name(name string) string {
	if name == 'IOError' || name == 'EnvironmentError' {
		return 'OSError'
	}
	return name
}

// Registration is name-based, not a Python type/metaclass implementation.
// Duplicate names replace their previous registration. Base names may be
// registered later. Cycles are bounded by exception_bases' visited set.
pub fn register_exception(name string, bases []string) {
	mut state := unsafe { runtime_state }
	state.registered[canonical_exception_name(name)] = bases.clone()
}

fn exception_bases(name string) []string {
	root := canonical_exception_name(name)
	mut pending := []string{}
	mut visited := [root]
	mut out := []string{}
	if root in runtime_state.registered {
		pending << runtime_state.registered[root]
	} else if root in builtin_bases {
		pending << builtin_bases[root]
	} else {
		pending << 'Exception'
	}
	mut position := 0
	for position < pending.len {
		base := canonical_exception_name(pending[position])
		position = position + 1
		if base in visited {
			continue
		}
		visited << base
		out << base
		if base in runtime_state.registered {
			pending << runtime_state.registered[base]
		} else if base in builtin_bases {
			pending << builtin_bases[base]
		} else {
			pending << 'Exception'
		}
	}
	return out
}

pub struct PyError {
	Error
pub:
	class_name       string
	bases            []string
	args             []Value
	cause            IError = none
	suppress_context bool
}

// This returns str(the_exception), without a diagnostic "ClassName: " prefix.
// This intentionally corrects the sample's prefix to meet Python message text.
pub fn (e PyError) msg() string {
	if e.args.len == 0 {
		return ''
	}
	if e.args.len == 1 {
		if e.class_name == 'KeyError' || 'KeyError' in e.bases {
			return repr(e.args[0])
		}
		return str(e.args[0])
	}
	return repr(Value(new_tuple(e.args)))
}

pub fn exception(class_name string, args []Value) PyError {
	name := canonical_exception_name(class_name)
	return PyError{class_name: name, bases: exception_bases(name), args: args.clone()}
}

pub fn raise(class_name string, message string) IError {
	return IError(exception(class_name, [Value(message)]))
}

pub fn raise_from(class_name string, message string, cause IError) IError {
	name := canonical_exception_name(class_name)
	return IError(PyError{
		class_name: name
		bases: exception_bases(name)
		args: [Value(message)]
		cause: cause
		suppress_context: true
	})
}

// KeyError must retain its actual key. raise('KeyError', text) instead means a
// STRING key, including the quotes that str(KeyError(text)) requires.
pub fn key_error(key Value) IError {
	return IError(exception('KeyError', [key]))
}

pub fn caught(err IError, classes ...string) ?PyError {
	if err is PyError {
		for name in classes {
			class_name := canonical_exception_name(name)
			if err.class_name == class_name || class_name in err.bases {
				return err
			}
		}
		return none
	}
	for name in classes {
		if name == 'Exception' || name == 'BaseException' {
			return exception('Exception', [Value(err.msg())])
		}
	}
	return none
}

pub enum Flow {
	normal
	return_
	break_
	continue_
	raise_
}

pub struct Completion {
pub mut:
	flow  Flow
	value Value = none_
	err   IError = none
}

pub struct Maybe[T] {
pub:
	has   bool
	value T
}

pub fn some[T](v T) Maybe[T] {
	return Maybe[T]{has: true, value: v}
}

pub fn nothing[T]() Maybe[T] {
	return Maybe[T]{}
}
