module main

fn written_initializer(node ClassDef) ?FunctionDef {
	for stmt in node.body.reverse() {
		if stmt is FunctionDef && stmt.name == '__init__' {
			return stmt
		}
	}
	return none
}

// init_method_name keeps Python's init and __init__ distinct when both are defined.
fn init_method_name(node ClassDef) string {
	mut used := node.declarations.keys()
	for stmt in node.body {
		if stmt is FunctionDef && stmt.name != '__init__' {
			used << escape_leading_underscore(stmt.name)
		}
	}
	if 'init' !in used {
		return 'init'
	}
	mut name := 'py2v_init'
	for (name in used) {
		name += '_'
	}
	return name
}

fn (t &VTranspiler) emitted_init_method(class_name string) string {
	if init := t.resolve_init_constructor(Expr(Name{ id: class_name })) {
		return init.method_name
	}
	return 'init'
}

// Reserve source spellings and the compound names emitted for class members.
fn constructor_reserved_names(node Module, mut names map[string]bool) {
	for word in node.source_words {
		names[word] = true
		names[to_symbol_ident(word)] = true
		names[escape_local_decl(word)] = true
	}
	for stmt in node.body {
		if stmt is ClassDef {
			for field, _ in stmt.declarations {
				names[class_attr_symbol_name(stmt.name, field)] = true
			}
			for member in stmt.body {
				if member is FunctionDef {
					names['${emitted_class_name(stmt.name)}_${member.name}'] = true
					names[class_attr_symbol_name(stmt.name, member.name)] = true
				}
			}
		}
	}
}

fn collect_init_constructors(node Module, mut names map[string]bool) map[string]InitConstructor {
	mut found := map[string]InitConstructor{}
	mut classes := map[string]ClassDef{}
	for stmt in node.body {
		if stmt is ClassDef { classes[stmt.name] = stmt }
	}
	for stmt in node.body {
		if stmt !is ClassDef {
			continue
		}
		class_def := stmt as ClassDef
		initializer := written_initializer(class_def) or { continue }
		stem := 'py2v_new_' + to_symbol_ident(emitted_class_name(class_def.name))
		mut factory := stem
		mut suffix := 0
		for (factory in names) {
			suffix++
			factory = '${stem}_${suffix}'
		}
		names[factory] = true
		mut seen := map[string]bool{}
		reference_fields := init_required_reference_fields(class_def, classes, mut seen)
		unsupported := if reference_fields.len > 0 {
			'required_reference_field_' + reference_fields.join('_')
		} else {
			''
		}
		found[class_def.name] = InitConstructor{
			class_name:             class_def.name
			factory_name:           factory
			method_name:            init_method_name(class_def)
			init:                   initializer
			unsupported:            unsupported
			type_params:            class_def.type_params
			unresolved_init_fields: class_def.unresolved_init_fields
		}
	}
	return found
}

// Allocate names across the whole V module before emission, independent of
// which importing file is visited first.
fn register_init_constructors(parsed map[string]Module, mut registry ModuleRegistry) {
	mut used := map[string]map[string]bool{}
	mut keys := parsed.keys()
	keys.sort()
	for key in keys {
		v_module := registry.lookup(key).v_module
		mut names := (used[v_module] or { map[string]bool{} }).clone()
		constructor_reserved_names(parsed[key], mut names)
		used[v_module] = names
	}
	for key in keys {
		v_module := registry.lookup(key).v_module
		mut names := used[v_module].clone()
		for class_name, constructor in collect_init_constructors(parsed[key], mut names) {
			registry.init_constructors['${key}.${class_name}'] = InitConstructor{
				...constructor
				defining_module: key
			}
		}
		used[v_module] = names
		for stmt in parsed[key].body {
			if stmt is ImportFrom {
				module_path := init_relative_module(key, registry.lookup(key), stmt.level,
					stmt.mod or { '' })
				for alias in stmt.names {
					if alias.name != '*' {
						local := alias.asname or { alias.name }
						registry.init_import_bindings['${key}.${local}'] = join_dotted(module_path,
							alias.name)
					}
				}
			} else if stmt is Import {
				for alias in stmt.names {
					local := alias.asname or { alias.name.split('.')[0] }
					target := if alias.asname != none { alias.name } else { local }
					registry.init_import_bindings['${key}.${local}'] = target
				}
			} else if stmt is ClassDef {
				registry.init_import_bindings.delete('${key}.${stmt.name}')
			} else if stmt is FunctionDef {
				registry.init_import_bindings.delete('${key}.${stmt.name}')
			} else if stmt is Assign {
				for target in stmt.targets {
					if target is Name {
						registry.init_import_bindings.delete('${key}.${target.id}')
					}
				}
			} else if stmt is AnnAssign && stmt.target is Name {
				registry.init_import_bindings.delete('${key}.${(stmt.target as Name).id}')
			}
		}
	}
}

fn (mut t VTranspiler) prepare_init_constructors(node Module) {
	t.local_init_constructors = map[string]InitConstructor{}
	if t.emit_pub {
		for stmt in node.body {
			if stmt is ClassDef {
				if constructor := t.registry.init_constructors['${t.current_dotted}.${stmt.name}'] {
					t.local_init_constructors[stmt.name] = constructor
				}
			}
		}
	} else {
		mut names := map[string]bool{}
		constructor_reserved_names(node, mut names)
		t.local_init_constructors = collect_init_constructors(node, mut names)
	}
}

// Keep the Python import spelling for constructor resolution only. General
// name and import emission stays on the preexisting path.
fn (t VTranspiler) init_import_module(level int, mod string) string {
	return init_relative_module(t.current_dotted, t.registry.lookup(t.current_dotted), level, mod)
}

fn (t VTranspiler) init_star_names(dotted string) []string {
	info := t.registry.lookup(dotted)
	mut names := map[string]bool{}
	for name in info.symbols {
		names[name] = true
	}
	prefix := info.dotted + '.'
	for binding, _ in t.registry.init_import_bindings {
		if info.dotted != '' && binding.starts_with(prefix) {
			name := binding[prefix.len..]
			if !name.contains('.') {
				names[name] = true
			}
		}
	}
	return names.keys().filter(!it.starts_with('_'))
}

fn init_relative_module(dotted string, info PyModuleInfo, level int, mod string) string {
	if level == 0 {
		return mod
	}
	mut parts := dotted.split('.').filter(it != '')
	if v_file_stem(info.v_relpath) != '' && parts.len > 0 {
		parts = parts[..parts.len - 1]
	}
	for _ in 1 .. level {
		if parts.len > 0 {
			parts = parts[..parts.len - 1]
		}
	}
	return join_dotted(parts.join('.'), mod)
}

fn (t VTranspiler) init_python_path(expr Expr) string {
	match expr {
		Name {
			if expr.id in t.local_idents || expr.id in t.module_idents
				|| expr.id in t.renamed_idents || t.escaped_identifiers[expr.id]
				|| t.is_bound_in_scope(expr.id) {
				return ''
			}
			return t.init_import_aliases[expr.id] or { '' }
		}
		Attribute {
			prefix := t.init_python_path(expr.value)
			return if prefix == '' { '' } else { prefix + '.' + expr.attr }
		}
		else { return '' }
	}
}

const max_reexport_hops = 16

fn (t VTranspiler) imported_init_constructor(path string) ?InitConstructor {
	if path == '' {
		return none
	}
	mut target := path
	mut seen := map[string]bool{}
	// A chain of re-exports is short. A cycle of module aliases can grow the path
	// without ever repeating it, so the walk is bounded: past the bound the name is
	// not a known class.
	mut hops := 0
	for !seen[target] {
		hops++
		if hops > max_reexport_hops {
			return none
		}
		seen[target] = true
		info := t.registry.lookup(target.all_before_last('.'))
		if info.dotted != '' {
			canonical := '${info.dotted}.${target.all_after_last('.')}'
			if binding := t.registry.init_import_bindings[canonical] {
				target = binding
				continue
			}
			return t.registry.init_constructors[canonical] or { return none }
		}
		// A package can re-export a module alias as well as a class.
		parts := target.split('.')
		mut replaced := false
		for i := parts.len - 1; i > 0; i-- {
			prefix := parts[..i].join('.')
			owner := t.registry.lookup(prefix.all_before_last('.'))
			canonical := '${owner.dotted}.${prefix.all_after_last('.')}'
			if owner.dotted != '' {
				if binding := t.registry.init_import_bindings[canonical] {
					target = binding + '.' + parts[i..].join('.')
					replaced = true
					break
				}
			}
		}
		if !replaced {
			return none
		}
	}
	return none
}

fn (t VTranspiler) resolve_init_constructor(expr Expr) ?InitConstructor {
	if expr is Name {
		if expr.id in t.local_idents || expr.id in t.module_idents
			|| expr.id in t.renamed_idents || t.escaped_identifiers[expr.id] {
			return none
		}
		if expr.id in t.init_import_aliases {
			return t.imported_init_constructor(t.init_import_aliases[expr.id])
		}
		return t.local_init_constructors[expr.id] or { return none }
	}
	return t.imported_init_constructor(t.init_python_path(expr))
}

fn (mut t VTranspiler) visit_init_constructor(node Call) ?string {
	if t.current_classmethod && node.func is Name && (node.func as Name).id == 'cls' {
		if info := t.local_init_constructors[t.current_class_name] {
			return t.init_constructor_error(info, 'dynamic_cls')
		}
	}
	info := t.resolve_init_constructor(node.func) or { return none }
	mut factory := info.factory_name
	if info.defining_module != '' {
		owner := t.registry.lookup(info.defining_module)
		if owner.v_module != '' && owner.v_module != t.module_name {
			t.add_using(owner.v_module)
			factory = owner.v_module + '.' + factory
		}
	}
	return t.render_init_call(info, factory, node)
}
