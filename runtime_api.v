module main

import x.json2

// RuntimeFunction is a module-level function of the runtime library, as its manifest
// (pyrt/api.json) describes it.
struct RuntimeFunction {
	v_name  string            // the function's name in the V module
	raises  bool              // it returns a result
	boxed   []bool            // per positional parameter: it takes a runtime value
	options map[string]string // Python keyword -> field of the options struct
}

struct ApiParam {
	name    string
	typ     string @[json: 'type']
	default string // the Python default as the manifest writes it, `b''`
}

struct ApiEntry {
	python  string
	v       string
	kind    string
	raises  bool
	params  []ApiParam
	options map[string]string
}

// runtime_functions maps the Python spelling of a call (`json.loads`) to the runtime
// function that answers it. The manifest is read at compile time, so the table is always
// the one of the runtime this py2v ships.
const runtime_functions = load_runtime_functions()

fn load_runtime_functions() map[string]RuntimeFunction {
	text := $embed_file('pyrt/api.json').to_string()
	entries := json2.decode[[]ApiEntry](text) or { return map[string]RuntimeFunction{} }
	mut table := map[string]RuntimeFunction{}
	for e in entries {
		// `module.function` only: methods and constructors need the receiver's type.
		if e.kind == 'function' && e.python.count('.') == 1 {
			table[e.python] = RuntimeFunction{
				v_name:  e.v
				raises:  e.raises
				boxed:   e.params.map(it.typ == 'Any')
				options: e.options.clone()
			}
		}
	}
	return table
}

// RuntimeEntry is any entry of the manifest, by its Python name (`datetime.datetime.now`).
struct RuntimeEntry {
	v_module string // `pyrt.datetime`
	v_name   string
	kind     string // function, constructor, method, property, constant, class
	raises   bool
	params   []ApiParam
	options  map[string]string
	v_access string   // for a property: `field` or `method`
	returns  string   // the Python type the manifest states, `sqlite3.Row | None`
	variadic bool     // the last parameter takes the remaining arguments
	boxed    []string // the options whose V field holds a runtime value
	v_type   string   // for a class: its V type, `logging.Logger`
	v_import string   // and the module that declares it, `pyrt.logging`
	v_ref    bool     // whether values of the class are references in V
}

struct ApiFullEntry {
	python        string
	v             string
	v_mod         string @[json: 'module']
	kind          string
	raises        bool
	params        []ApiParam
	options       map[string]string
	option_params []ApiParam
	v_access      string
	returns       string
	variadic      bool
	v_type        string
	v_import      string
	v_ref         bool
}

const runtime_api = load_runtime_api()

// runtime_library_modules are the Python modules whose calls the frontend resolves through
// the manifest (`_RUNTIME_API_MODULES` in frontend/ast_dump.py).
const runtime_library_modules = ['datetime', 'sqlite3', 'pathlib', 'logging', 'argparse', 'subprocess',
	'hashlib', 'uuid', 'shutil', 'tempfile', 'base64', 'secrets', 'mcp']

fn load_runtime_api() map[string]RuntimeEntry {
	text := $embed_file('pyrt/api.json').to_string()
	entries := json2.decode[[]ApiFullEntry](text) or { return map[string]RuntimeEntry{} }
	mut table := map[string]RuntimeEntry{}
	for e in entries {
		table[e.python] = RuntimeEntry{
			v_module: e.v_mod
			v_name:   e.v
			kind:     e.kind
			raises:   e.raises
			params:   e.params
			options:  e.options.clone()
			v_access: e.v_access
			returns:  e.returns
			variadic: e.variadic
			boxed:    e.option_params.filter(it.typ.contains('Any') || it.typ.starts_with('dict')
				|| it.typ.starts_with('Mapping')).map(it.name)
			v_type:   e.v_type
			v_import: e.v_import
			v_ref:    e.v_ref
		}
	}
	// The output of a finished process read as text (pyrt/subprocess/text.v).
	for stream in ['stdout', 'stderr'] {
		table['subprocess.CompletedProcess.${stream}_text'] = RuntimeEntry{
			v_module: 'pyrt.subprocess'
			v_name:   '${stream}_text'
			kind:     'method'
		}
	}
	// The typed readers of a parsed namespace, chosen by the frontend from `add_argument`.
	for reader in ['get_str', 'get_int', 'get_float', 'get_bool', 'get_strings', 'require'] {
		table['argparse.Namespace.${reader}'] = RuntimeEntry{
			v_module: 'pyrt.argparse'
			v_name:   reader
			kind:     'method'
			raises:   true
			params:   [ApiParam{
				name: 'name'
				typ:  'str'
			}]
		}
	}
	// A row read by column name: the manifest lists only the indexed form.
	table['sqlite3.Row.by_name'] = RuntimeEntry{
		v_module: 'pyrt.sqlite3'
		v_name:   'by_name'
		kind:     'method'
		raises:   true
	}
	return table
}

// runtime_class_types gives the V import and type of a runtime library class named in an
// annotation. (The manifest names the constructors but not the types; this table goes when
// it does.) The sqlite3 objects are references, as `connect` and `execute` return them.
const runtime_class_types = {
	'datetime.datetime':  'pyrt.datetime|datetime.Datetime'
	'datetime.date':      'pyrt.datetime|datetime.Date'
	'datetime.timedelta': 'pyrt.datetime|datetime.Timedelta'
	'datetime.timezone':  'pyrt.datetime|datetime.Timezone'
	'sqlite3.Connection': 'pyrt.sqlite3|&sqlite3.Connection'
	'sqlite3.Cursor':     'pyrt.sqlite3|&sqlite3.Cursor'
	'sqlite3.Row':        'pyrt.sqlite3|sqlite3.Row'
	'pathlib.Path':       'pyrt.pathlib|pathlib.Path'
}

// runtime_positional_options gives, for a callable whose later Python parameters are fields
// of an options struct in V, those parameters in Python's positional order. (The manifest
// lists the options without their order; this table goes when it carries one.)
const runtime_positional_options = {
	'datetime.datetime':  ['hour', 'minute', 'second', 'microsecond', 'tzinfo']
	'datetime.timedelta': ['days', 'seconds', 'microseconds', 'milliseconds', 'minutes', 'hours',
		'weeks']
}

// runtime_api_call emits a call of a runtime function or constructor that the frontend
// resolved (`node.api`): the V name, positional arguments (boxed where the parameter takes
// any value), keyword and option arguments as fields of the options struct, and, as py2v's
// functions do not return results yet, a handler that stops the program where it can raise.
fn (mut t VTranspiler) runtime_api_call(node Call) ?string {
	entry := runtime_api[node.api] or { return none }
	if entry.kind == 'method' {
		return t.runtime_api_method(node, entry)
	}
	if entry.kind !in ['function', 'constructor'] {
		return none
	}
	t.add_using(entry.v_module)
	mut positional := []string{}
	mut named := []string{}
	for i, arg in node.args {
		if arg is Starred {
			return none
		}
		code := t.visit_expr(arg)
		param := if i < entry.params.len { entry.params[i] } else { ApiParam{} }
		if i >= entry.params.len && entry.variadic && entry.params.len > 0 {
			// one of the remaining arguments of a variadic parameter
			positional << if entry.params.last().typ.contains('Any') {
				'pyrt.box(${code})'
			} else {
				code
			}
			continue
		}
		if i >= entry.params.len {
			// A positional argument past the V function's own parameters is one of the
			// options, in Python's positional order for this callable.
			order := runtime_positional_options[node.api] or { return none }
			name := order[i - entry.params.len] or { return none }
			named << '${entry.options[name] or { name }}: ${code}'
			continue
		}
		if field := entry.options[param.name] {
			named << '${field}: ${code}'
		} else if param.typ == 'Any' {
			positional << 'pyrt.box(${code})'
		} else {
			positional << code
		}
	}
	for kw in node.keywords {
		name := kw.arg or { return none }
		field := entry.options[name] or { name }
		code := t.visit_expr(kw.value)
		// an option the runtime keeps as a runtime value (a JSON schema, a payload)
		named << if name in entry.boxed && !code.starts_with('pyrt.') {
			'${field}: pyrt.box(${code})'
		} else {
			'${field}: ${code}'
		}
	}
	// A parameter left out whose default is empty bytes: the V function takes it always.
	for i := positional.len; i < entry.params.len; i++ {
		if entry.params[i].default != "b''" || entry.params[i].name in entry.options {
			break
		}
		positional << '[]u8{}'
	}
	positional << named
	call := '${entry.v_module.all_after_last('.')}.${entry.v_name}(${positional.join(', ')})'
	return if entry.raises { '(${call} or { pyrt.fail(err) })' } else { call }
}

// runtime_api_method emits a method call on a runtime object the frontend resolved. A
// parameter that takes a sequence of any values (the parameters of `execute`) takes each
// element of a tuple or list display boxed, or one boxed value otherwise.
fn (mut t VTranspiler) runtime_api_method(node Call, entry RuntimeEntry) ?string {
	if node.func !is Attribute {
		return none
	}
	mut receiver := t.visit_expr((node.func as Attribute).value)
	if receiver.contains(' or {') && !receiver.starts_with('(') {
		receiver = '(${receiver})'
	}
	// A method called straight on a result that may be None, `cur.fetchone()[0]`: Python
	// raises a TypeError there, and V has to unwrap the option before the call.
	inner := (node.func as Attribute).value
	if inner is Name && inner.api == 'sqlite3.must_row' {
		// a row that may be None; the helper also takes one V has already unwrapped
		t.add_using('pyrt.sqlite3')
		receiver = 'sqlite3.must_row(${receiver})'
	}
	if inner is Call && inner.api != '' {
		if made := runtime_api[inner.api] {
			if made.returns.contains('| None') && !made.raises {
				receiver = '(${receiver} or { panic("TypeError: \'NoneType\' object is not subscriptable") })'
			}
		}
	}
	mut args := []string{}
	for i, arg in node.args {
		if arg is Starred {
			return none
		}
		mut param := if i < entry.params.len { entry.params[i] } else { ApiParam{} }
		if i >= entry.params.len && entry.variadic && entry.params.len > 0 {
			param = entry.params.last()
		}
		if param.typ.contains('Any') {
			t.add_using('pyrt')
			elements := match arg {
				Tuple { arg.elts }
				List { arg.elts }
				else { []Expr{} }
			}
			if arg is Tuple || arg is List {
				for element in elements {
					args << 'pyrt.box(${t.visit_expr(element)})'
				}
			} else {
				args << 'pyrt.box(${t.visit_expr(arg)})'
			}
		} else {
			args << t.visit_expr(arg)
		}
	}
	// A keyword names the next positional parameter or a field of the options struct.
	for kw in node.keywords {
		name := kw.arg or { return none }
		mut code := t.visit_expr(kw.value)
		if field := entry.options[name] {
			if field == 'value_type' {
				// `type=int`: the runtime's enum of the conversions it knows
				value := kw.value
				kind := if value is Name { value.id } else { '' }
				if kind !in ['str', 'int', 'float'] {
					return none
				}
				code = '.${kind}_type'
			}
			args << '${field}: ${code}'
		} else if args.len < entry.params.len && entry.params[args.len].name == name
			&& !entry.params[args.len].typ.contains('Any') {
			args << code
		} else {
			return none
		}
	}
	if node.api in ['argparse.ArgumentParser.parse_args', 'argparse.ArgumentParser.parse_known_args']
		&& args.len == 0 {
		// with no argument Python parses the program's own arguments
		t.add_using('pyrt.pysys')
		args << 'pysys.argv()[1..]'
	}
	call := '${receiver}.${entry.v_name}(${args.join(', ')})'
	return if entry.raises { '${call} or { pyrt.fail(err) }' } else { call }
}
