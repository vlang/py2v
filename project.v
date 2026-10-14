module main

// PyModuleInfo describes one Python module discovered during project scanning.
pub struct PyModuleInfo {
pub:
	// dotted is the Python import path, e.g. `portage.util.digraph`.
	dotted string
	// v_module is the V module the file belongs to, e.g. `py_portage_util`.
	v_module string
	// v_relpath is the output path relative to the output root, e.g.
	// `py_portage_util/digraph.v`.
	v_relpath string
	// symbols are the top-level names this module defines.
	symbols []string
}

// ModuleRegistry records the Python module layout of a project so that the
// transpiler can turn cross-module imports into V module references.
//
// V resolves a directory as a single module: every `.v` file in `util/` must
// declare `module util` and its symbols merge into one namespace. Python has no
// such sharing, so the registry also tracks which symbols each Python module
// defines in order to detect collisions early.
pub struct ModuleRegistry {
pub mut:
	// by_dotted maps a Python dotted path to its module info.
	by_dotted map[string]PyModuleInfo
	// root_dotted is the Python package the scan started from, e.g. `portage`.
	root_dotted string
	// output_root is the directory that maps to root_dotted.
	output_root string
	// class_fields_by_path maps `module.Class` to its ordered field list.
	class_fields_by_path map[string][]string
	// class_bases_by_path maps `module.Class` to its base class names, so a
	// struct literal built in another module can fill the embedded bases.
	class_bases_by_path map[string][]string
	// mut_methods names `Class.method` pairs that need a `mut` V receiver.
	mut_methods map[string]bool
}

// new_module_registry creates an empty registry.
pub fn new_module_registry() ModuleRegistry {
	return ModuleRegistry{
		by_dotted:   map[string]PyModuleInfo{}
		root_dotted: ''
		output_root: ''
	}
}

// add_module registers one discovered module under a Python import path.
pub fn (mut r ModuleRegistry) add_module(info PyModuleInfo) {
	r.by_dotted[info.dotted] = info
}

// add_module_under registers the same module under every Python import path it
// can legitimately be reached by.
//
// A file found at `portage/util/x.py` under a scan root named `lib` is named
// `portage.util.x` by the import statements in the source, but the scanner can
// only derive `lib.portage.util.x` from the directory it was pointed at.
// Registering both keys lets either spelling resolve without guessing at
// suffixes, which would happily bind `portage.util` to an unrelated `util`.
pub fn (mut r ModuleRegistry) add_module_under(info PyModuleInfo, aliases []string) {
	r.by_dotted[info.dotted] = info
	for alias in aliases {
		if alias != '' && alias != info.dotted {
			r.by_dotted[alias] = info
		}
	}
}

// dotted_keys returns every registered Python import path, without duplicates
// from the alias registration above.
pub fn (r ModuleRegistry) dotted_keys() []string {
	return r.by_dotted.keys()
}

// resolve finds the registry entry for a Python module path. An empty string is
// returned when the module is not part of the scanned project.
pub fn (r ModuleRegistry) resolve(dotted string) !PyModuleInfo {
	return r.by_dotted[dotted] or {
		return error('module not in project: ${dotted}')
	}
}

// lookup returns the registry entry for a Python module path, or the zero value.
pub fn (r ModuleRegistry) lookup(dotted string) PyModuleInfo {
	return r.by_dotted[dotted] or { PyModuleInfo{} }
}

// contains reports whether a Python module path belongs to the scanned project.
pub fn (r ModuleRegistry) contains(dotted string) bool {
	return dotted in r.by_dotted
}

// is_project_root reports whether `dotted` is the scanned project's root package.
pub fn (r ModuleRegistry) is_project_root(dotted string) bool {
	return dotted == r.root_dotted
}

// v_module_for returns the V module a Python module path maps to.
pub fn (r ModuleRegistry) v_module_for(dotted string) string {
	info := r.lookup(dotted)
	return info.v_module
}

// import_prefix_for returns the V expression prefix needed to reach a symbol
// exported by `dotted`. Symbols in the current module need no prefix; symbols
// reached through a `from X import Y` where X resolves into the project do.
//
// The current module is passed explicitly because a symbol may be defined in the
// current module while the same name is also visible elsewhere.
pub fn (r ModuleRegistry) import_prefix_for(dotted string, current_v_module string) string {
	info := r.lookup(dotted)
	if info.dotted == '' {
		return ''
	}
	if info.v_module == current_v_module {
		return ''
	}
	return info.v_module
}

// find_symbol_module returns the Python module that defines `symbol`, so that a
// bare reference can be qualified. Symbols defined by the current module win.
pub fn (r ModuleRegistry) find_symbol_module(symbol string, current_dotted string) string {
	if current_dotted != '' {
		cur := r.lookup(current_dotted)
		if cur.dotted != '' && symbol in cur.symbols {
			return current_dotted
		}
	}
	for dotted, info in r.by_dotted {
		if symbol in info.symbols {
			return dotted
		}
	}
	return ''
}

// collisions returns symbols defined by more than one file in the same V
// module, which V will reject as redefinitions.
pub fn (r ModuleRegistry) collisions() map[string][]string {
	mut seen := map[string]string{} // symbol -> first owning module
	mut owner := map[string]string{} // v_relpath -> dotted, for de-duplication
	mut dupes := map[string][]string{}
	for dotted, info in r.by_dotted {
		// A file registered under several import paths must only be visited
		// once, or every one of its symbols looks like a duplicate.
		if owner[info.v_relpath] != '' {
			continue
		}
		owner[info.v_relpath] = dotted
		for sym in info.symbols {
			if sym in seen {
				key := '${info.v_module}.${sym}'
				if key !in dupes {
					dupes[key] = [seen[sym]]
				}
				if dotted !in dupes[key] {
					dupes[key] << dotted
				}
			} else {
				seen[sym] = dotted
			}
		}
	}
	return dupes
}

// py_dotted_from_path converts a path relative to the scan root into a Python
// dotted path, dropping any `.py` suffix. A trailing `__init__` segment is
// dropped too, because a package `__init__` is importable as the package itself.
pub fn py_dotted_from_path(rel string) string {
	mut p := rel.replace('\\', '/')
	if p.starts_with('./') {
		p = p[2..]
	}
	if p.ends_with('.py') {
		p = p[..p.len - 3]
	}
	mut parts := p.split('/').filter(it.len > 0 && it != '.')
	if parts.len > 0 && parts[parts.len - 1] == '__init__' {
		parts = parts[..parts.len - 1]
	}
	return parts.join('.')
}

// py_stem_from_path returns just the file stem of a path: `sub/calc.py` gives
// `calc` and `sub/__init__.py` gives an empty string.
pub fn py_stem_from_path(rel string) string {
	p := rel.replace('\\', '/')
	mut stem := p.all_after_last('/')
	if stem == p {
		stem = p
	}
	if stem.ends_with('.py') {
		stem = stem[..stem.len - 3]
	}
	if stem == '__init__' {
		return ''
	}
	return stem
}

// py_pkg_dotted returns the owning package of a file, expressed relative to the
// scan root. `portage/util/x.py` is owned by `portage.util`, and a file sitting
// directly in the scan root yields an empty string.
//
// The package, not the file, decides the V module, because in Python a package
// `__init__.py` shares one namespace with its sibling modules. Merging by
// directory therefore matches Python's own visibility rules.
pub fn py_pkg_dotted(rel string) string {
	p := rel.replace('\\', '/')
	dir := p.all_before_last('/')
	if dir == p {
		return ''
	}
	return py_dotted_from_path(if dir == '' { '.' } else { dir })
}

// qualify_pkg_dotted turns the scan-relative package name into the name the
// package is actually imported by.
//
// A scan root that is itself a package contributes its own name, so
// `--package .../pkg_multi` makes `sub/calc.py` live in `pkg_multi.sub`. A scan
// root that merely contains packages, as `--package portage/lib` does, does not,
// so `portage/util/x.py` stays `portage.util` and `_emerge/main.py` stays
// `_emerge.main`. Both spellings are needed because the source imports by the
// name it sees on sys.path, which the scanner cannot infer from a directory.
pub fn qualify_pkg_dotted(rel_pkg string, root_dotted string, root_is_package bool) string {
	if rel_pkg == '' {
		return root_dotted
	}
	if root_is_package {
		return root_dotted + '.' + rel_pkg
	}
	return rel_pkg
}

// join_dotted concatenates non-empty dotted segments with separators.
pub fn join_dotted(parts ...string) string {
	mut kept := []string{}
	for p in parts {
		if p != '' {
			kept << p
		}
	}
	return kept.join('.')
}

// py_mod_dotted returns the importable dotted name of a file relative to the
// scan root. A package `__init__.py` is importable as its package name.
pub fn py_mod_dotted(rel string) string {
	return join_dotted(py_pkg_dotted(rel), py_stem_from_path(rel))
}

// v_module_prefix keeps generated module names distinguishable from vlib ones.
const v_module_prefix = 'py_'

// sanitize_v_module_name turns a dotted Python path into a legal V module name:
// characters V does not accept become underscores and a leading underscore,
// which V rejects outright, is dropped.
pub fn sanitize_v_module_name(dotted string) string {
	mut out := []u8{}
	for ch in dotted {
		is_alpha := (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
		is_digit := ch >= `0` && ch <= `9`
		if is_alpha || is_digit {
			out << ch
		} else {
			out << `_`
		}
	}
	name := out.bytestr().trim_left('_')
	if name == '' {
		return v_module_prefix + 'root'
	}
	return v_module_prefix + name
}

// v_module_for_pkg returns the V module that owns a Python package.
//
// The name is always prefixed and never nested inside another generated
// directory. V names a module after the directory that holds it and searches
// those directories for an `import`, so a directory called `sync` would shadow
// vlib's `sync` for every module in the project, and a directory called `_x`
// would be rejected as an illegal module name.
pub fn v_module_for_pkg(pkg_dotted string) string {
	return sanitize_v_module_name(pkg_dotted)
}

// v_stem_for returns the output file name for one Python file: `__init__.py`
// becomes `__init__.v` so that a package's namespace and its siblings stay in
// one V module without a synthetic name.
pub fn v_stem_for(rel string) string {
	p := rel.replace('\\', '/')
	mut stem := p.all_after_last('/')
	if stem == p {
		stem = p
	}
	if stem == '__init__.py' {
		return '__init__.v'
	}
	if stem.ends_with('.py') {
		return stem[..stem.len - 3] + '.v'
	}
	return stem
}

// v_relpath_for returns the output path for one Python file, relative to the
// output root: `<v_module>/<stem>.v`.
pub fn v_relpath_for(v_module string, rel string) string {
	return v_module + '/' + v_stem_for(rel)
}

// PyClassInfo describes a Python class discovered during the project scan.
pub struct PyClassInfo {
pub:
	dotted      string
	name        string
	fields      []string
	bases       []string
	is_protocol bool
}

// class_bases returns the base class names of a class defined in `dotted`.
pub fn (r ModuleRegistry) class_bases(dotted string, class_name string) []string {
	info := r.lookup(dotted)
	if info.dotted == '' {
		return []string{}
	}
	if bases := r.class_bases_by_path['${dotted}.${class_name}'] {
		return bases
	}
	return []string{}
}

// class_named returns the classes the scanned project defines, keyed by bare
// class name, so a consumer can resolve a class it only reached by importing a
// symbol from its module.
pub fn (r ModuleRegistry) class_named(class_name string) PyClassSummary {
	mut empty := PyClassSummary{ name: class_name }
	for dotted, _ in r.by_dotted {
		fields := r.class_fields(dotted, class_name)
		if fields.len == 0 {
			continue
		}
		return PyClassSummary{
			name:   class_name
			fields: fields
			bases:  r.class_bases(dotted, class_name)
		}
	}
	return empty
}

// class_fields returns the field list of a class defined in `dotted`, or an
// empty array when the module does not define that class.
pub fn (r ModuleRegistry) class_fields(dotted string, class_name string) []string {
	info := r.lookup(dotted)
	if info.dotted == '' {
		return []string{}
	}
	if fields := r.class_fields_by_path['${dotted}.${class_name}'] {
		return fields
	}
	return []string{}
}

// dotted_for_v_module returns the Python dotted path registered for a V module
// name, or an empty string when the V module is not part of the project.
pub fn (r ModuleRegistry) dotted_for_v_module(v_module string) string {
	for dotted, info in r.by_dotted {
		if info.v_module == v_module {
			return dotted
		}
	}
	return ''
}

// symbols_named_in returns the top-level symbols of a module.
pub fn (r ModuleRegistry) symbols_named_in(dotted string) []string {
	info := r.lookup(dotted)
	if info.dotted == '' {
		return []string{}
	}
	return info.symbols
}
