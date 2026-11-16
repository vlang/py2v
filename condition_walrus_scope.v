module main

fn (mut t VTranspiler) prepare_condition_walruses(names []string, parameters []Arg) {
	t.condition_walrus_vars = map[string]bool{}
	t.condition_walrus_types = map[string]string{}
	t.condition_walrus_order = names.clone()
	t.condition_walrus_initial = map[string]string{}
	for name in t.condition_walrus_order {
		mut spelling := escape_local_decl(name)
		if name == '_' { spelling = t.new_tmp('walrus_name') }
		for parameter in parameters {
			if parameter.arg == name {
				// Python rebinding is local; do not introduce a mut parameter or
				// change the caller's value when the walrus targets a parameter.
				initial := t.visit_name(Name{ id: name })
				spelling = t.new_tmp('walrus_arg')
				t.condition_walrus_initial[name] = initial
				break
			}
		}
		t.condition_walrus_vars[name] = true
		t.local_idents[name] = spelling
		t.note_scope_binding(name)
	}
}

fn (t VTranspiler) lower_this_condition(node If) bool {
	if t.condition_walrus_vars.len == 0 { return false }
	if !node.lower_condition_walrus || !condition_walrus_supported(*node.test) { return false }
	mut targets := []string{}
	condition_walrus_targets(*node.test, mut targets)
	for name in targets {
		if !t.condition_walrus_vars[name] { return false }
	}
	return true
}

// Render after the body: expression emission has then populated its type
// table, even when an earlier assignment supplied the type of the RHS.
fn (mut t VTranspiler) condition_walrus_declarations() string {
	mut lines := []string{}
	for name in t.condition_walrus_order {
		spelling := t.local_idents[name]
		if initial := t.condition_walrus_initial[name] {
			lines << 'mut ${spelling} := ${initial}'
			continue
		}
		typ := t.condition_walrus_types[name] or { t.var_types[name] }
		if typ == 'bool' || typ == 'string' || typ.starts_with('[]') || typ.starts_with('map[') {
			lines << 'mut ${spelling} := ${t.zero_value_for(typ)}'
		} else if typ in v_width_rank {
			zero := if typ == 'int' { '0' } else { '${typ}(0)' }
			lines << 'mut ${spelling} := ${zero}'
		} else {
			// No guessed primitive type: leave an explicit build error for
			// unknown types, and do not run a struct's field defaults early.
			lines << "\$compile_error('py2v: cannot infer an inert zero value for walrus target ${name}')"
			lines << 'mut ${spelling} := 0'
		}
	}
	return lines.join('\n')
}
