module main

// PyModuleInfo describes one Python module discovered during project scanning.
pub struct PyModuleInfo {
pub:
	// dotted is the Python import path, e.g. `portage.util.digraph`.
	dotted string
	// v_module is the V module the file belongs to, e.g. `util`.
	v_module string
	// v_relpath is the output path relative to the output root, e.g. `util/digraph.v`.
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

// add_module registers one discovered module.
pub fn (mut r ModuleRegistry) add_module(info PyModuleInfo) {
	r.by_dotted[info.dotted] = info
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

// collisions returns symbols defined by more than one module in the same V
// module, which V will reject as redefinitions.
pub fn (r ModuleRegistry) collisions() map[string][]string {
	mut seen := map[string]string{} // symbol -> first owning module
	mut dupes := map[string][]string{}
	for dotted, info in r.by_dotted {
		for sym in info.symbols {
			if sym in seen {
				key := '${info.v_module}.${sym}'
				if key !in dupes {
					dupes[key] = [seen[sym]]
				}
				dupes[key] << dotted
			} else {
				seen[sym] = dotted
			}
		}
	}
	return dupes
}

// py_dotted_from_path converts a path relative to the scan root into a Python
// dotted module path. `__init__.py` maps to its containing package, and `.py`
// suffixes are dropped, mirroring Python's own import machinery.
pub fn py_dotted_from_path(rel string) string {
	mut p := rel.replace('\\', '/')
	if p.starts_with('./') {
		p = p[2..]
	}
	if p.ends_with('.py') {
		p = p[..p.len - 3]
	}
	mut parts := p.split('/').filter(it.len > 0 && it != '.')
	// Drop a trailing `__init__` segment: it names the package, not a module.
	if parts.len > 0 && parts[parts.len - 1] == '__init__' {
		parts = parts[..parts.len - 1]
	}
	return parts.join('.')
}

// v_relpath_from_py_path maps a Python dotted module path to the output file
// path, preserving the directory structure so that V merges each directory into
// one module.
//
// A package `__init__.py` is written inside its own directory (as `mod.v`) so
// that it shares the V module with that directory's submodules instead of
// creating a second module with the same name.
pub fn v_relpath_from_py_path(dotted string) string {
	parts := dotted.split('.').filter(it.len > 0)
	if parts.len <= 1 {
		return 'main.v'
	}
	if parts[parts.len - 1] == '__init__' {
		dir := if parts.len > 2 { parts[1..parts.len - 1].join('/') } else { '' }
		return dir + '/mod.v'
	}
	return parts[1..].join('/') + '.v'
}

// v_module_from_py_path returns the V module for a Python dotted path. Every
// module below the root package shares the V module named after its top-level
// subdirectory, because V merges a directory into a single module.
pub fn v_module_from_py_path(dotted string, root_dotted string) string {
	root_parts := root_dotted.split('.').filter(it.len > 0)
	parts := dotted.split('.').filter(it.len > 0)
	if parts.len > root_parts.len {
		return parts[root_parts.len]
	}
	return 'main'
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

// symbols_named_in returns the top-level symbols of a module.
pub fn (r ModuleRegistry) symbols_named_in(dotted string) []string {
	info := r.lookup(dotted)
	if info.dotted == '' {
		return []string{}
	}
	return info.symbols
}
