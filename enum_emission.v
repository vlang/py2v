module main

// native_enum_base identifies a plain enum that the frontend proved can use V members.
fn native_enum_base(base Expr) bool {
	return enum_base_api(base) in ['__py2v__.nominal_enum', '__py2v__.named_enum']
}

fn enum_base_api(base Expr) string {
	return match base {
		Name { base.api }
		Attribute { base.api }
		else { '' }
	}
}

// visit_nominal_enum emits members with their own type and preserves the Python member labels.
fn (mut t VTranspiler) visit_nominal_enum(node ClassDef, name string) string {
	t.nominal_enums[node.name] = true
	named := enum_base_api(node.bases[0]) == '__py2v__.named_enum'
	mut members := []string{}
	mut labels := []string{}
	mut names := []string{}
	mut lookup := []string{}
	mut symbols := map[string]string{}
	for statement in node.body {
		if statement is Assign && statement.targets.len == 1 && statement.targets[0] is Name {
			python_name := (statement.targets[0] as Name).id
			member := escape_keyword(python_name.to_lower())
			members << '\t${member} = ${t.visit_expr(statement.value)}'
			labels << "\t\t.${member} { '${node.name}.${python_name}' }"
			if named {
				names << "\t\t.${member} { '${python_name}' }"
				lookup << "\t\t'${python_name}' { .${member} }"
			}
			symbols[python_name] = '${name}.${member}'
		}
	}
	t.class_attr_symbols[node.name] = symbols
	mut declarations := ['pub enum ${name} {\n${members.join('\n')}\n}',
		'pub fn (member ${name}) str() string {\n\treturn match member {\n${labels.join('\n')}\n\t}\n}']
	if named {
		t.add_using('pyrt')
		declarations << 'pub fn (member ${name}) py2v_enum_name() string {\n\treturn match member {\n${names.join('\n')}\n\t}\n}'
		declarations << 'pub fn ${name}.py2v_enum_lookup(label string) !${name} {\n\treturn match label {\n${lookup.join('\n')}\n\t\telse { return pyrt.key_error(pyrt.Value(label)) }\n\t}\n}'
	}
	for statement in node.body {
		if statement is FunctionDef {
			declarations << t.visit_function_def(FunctionDef{
				...statement
				is_class_method: true
				class_name:      node.name
			})
		}
	}
	return declarations.join('\n\n')
}
