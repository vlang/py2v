module argparse

import pyrt

fn spaces(count int) string {
    mut out := ''
    for _ in 0 .. count { out = out + ' ' }
    return out
}

fn words(text string) []string {
    split := pyrt.call_method(pyrt.Value(text), 'split', []pyrt.Value{}) or { return [text] }
    return pyrt.as_strings(split) or { return [text] }
}

fn wrap_text(text string, width int, first_indent string, next_indent string) string {
    mut out := ''
    mut line := first_indent
    mut has_words := false
    for word in words(text) {
        extra := if has_words { ' ' } else { '' }
        if has_words && line.runes().len + 1 + word.runes().len > width {
            out = out + line + '\n'
            line = next_indent + word
        } else { line = line + extra + word }
        has_words = true
    }
    if has_words { out = out + line + '\n' }
    return out
}

fn (a &Argument) metavar_name() string {
    if a.metavar != '' { return a.metavar }
    if a.has_choices {
        mut choices := []string{}
        for value in a.choices { choices << pyrt.str(value) }
        return '{' + choices.join(',') + '}'
    }
    return if a.positional { a.dest } else { upper(a.dest) }
}

fn (a &Argument) value_usage() string {
    meta := a.metavar_name()
    if a.nargs == '?' { return '[' + meta + ']' }
    if a.nargs == '*' { return '[' + meta + ' ...]' }
    if a.nargs == '+' { return meta + ' [' + meta + ' ...]' }
    if a.nargs == '' { return meta }
    n := nargs_count(a.nargs) or { return meta }
    mut parts := []string{}
    for _ in 0 .. n { parts << meta }
    return parts.join(' ')
}

fn (a &Argument) usage_part() string {
    if a.positional { return a.value_usage() }
    if is_zero_argument(a.action) { return a.names[0] }
    return a.names[0] + ' ' + a.value_usage()
}

fn (a &Argument) help_invocation() string {
    if a.positional { return a.metavar_name() }
    if is_zero_argument(a.action) { return a.names.join(', ') }
    mut parts := []string{}
    for name in a.names { parts << name + ' ' + a.value_usage() }
    return parts.join(', ')
}

fn (p &ArgumentParser) help_text(a &Argument) string {
    text := a.help
    mut i := 0
    mut out := ''
    for i < text.len {
        if text[i] != 37 { out = out + text[i .. i + 1]; i = i + 1; continue }
        if i + 1 < text.len && text[i + 1] == 37 { out = out + '%'; i = i + 2; continue }
        if i + 1 < text.len && text[i + 1] == 40 {
            mut end := i + 2
            for end < text.len && text[end] != 41 { end = end + 1 }
            if end + 1 < text.len && text[end + 1] == 115 {
                key := text[i + 2 .. end]
                mut value := ''
                mut known := true
                if key == 'prog' { value = p.prog }
                else if key == 'default' { value = pyrt.str(a.default_value) }
                else if key == 'type' { value = value_type_name(a.value_type) }
                else if key == 'dest' { value = a.dest }
                else if key == 'const' { value = pyrt.str(a.constant) }
                else if key == 'choices' {
                    mut choices := []string{}
                    for option in a.choices { choices << pyrt.str(option) }
                    value = choices.join(', ')
                } else { known = false }
                if known { out = out + value; i = end + 2; continue }
            }
        }
        out = out + '%'
        i = i + 1
    }
    return out
}

pub fn (p &ArgumentParser) format_usage() string {
    if p.settings.usage == suppress { return '' }
    if p.settings.usage != '' { return 'usage: ' + replace_text(p.settings.usage, '%(prog)s', p.prog) + '\n' }
    mut parts := []string{}
    mut rendered_groups := map[string]bool{}
    for a in p.arguments {
        if a.positional || a.help == suppress { continue }
        if a.group_id >= 0 {
            key := a.group_id.str()
            if key in rendered_groups { continue }
            rendered_groups[key] = true
            group := p.groups[a.group_id]
            mut alternatives := []string{}
            for index in group.members {
                member := p.arguments[index]
                if member.help != suppress { alternatives << member.usage_part() }
            }
            if alternatives.len == 0 { continue }
            content := alternatives.join(' | ')
            parts << if group.required { '(' + content + ')' } else { '[' + content + ']' }
        } else {
            content := a.usage_part()
            parts << if a.required { content } else { '[' + content + ']' }
        }
    }
    for a in p.arguments { if a.positional && a.help != suppress { parts << a.usage_part() } }
    if p.subcommands.len > 0 { parts << p.subcommands[0].label() + ' ...' }
    mut line := 'usage: ' + p.prog
    mut out := ''
    continuation := spaces(7 + p.prog.runes().len)
    for part in parts {
        if line.runes().len + 1 + part.runes().len > 78 && line != 'usage: ' + p.prog {
            out = out + line + '\n'
            line = continuation + part
        } else { line = line + ' ' + part }
    }
    return out + line + '\n'
}

fn help_row(invocation string, description string, help_column int, extra_indent int) string {
    initial := spaces(2 + extra_indent) + invocation
    if description == '' { return initial + '\n' }
    indent := spaces(help_column)
    if initial.runes().len + 2 > help_column {
        return initial + '\n' + wrap_text(description, 78, indent, indent)
    }
    return wrap_text(description, 78, initial + spaces(help_column - initial.runes().len), indent)
}

pub fn (p &ArgumentParser) format_help() string {
    mut result := p.format_usage()
    if result != '' { result = result + '\n' }
    if p.settings.description != '' {
        result = result + wrap_text(replace_text(p.settings.description, '%(prog)s', p.prog), 78, '', '') + '\n'
    }
    mut max_width := 0
    for a in p.arguments {
        if a.help == suppress { continue }
        length := a.help_invocation().runes().len
        if length > max_width { max_width = length }
    }
    if p.subcommands.len > 0 {
        sub := p.subcommands[0]
        if sub.label().runes().len > max_width { max_width = sub.label().runes().len }
        for name in sub.names {
            if sub.descriptions[name] != '' && name.runes().len + 2 > max_width { max_width = name.runes().len + 2 }
        }
    }
    mut column := max_width + 4
    if column > 24 { column = 24 }
    mut positionals := ''
    mut options := ''
    for a in p.arguments {
        if a.help == suppress { continue }
        row := help_row(a.help_invocation(), p.help_text(a), column, 0)
        if a.positional { positionals = positionals + row } else { options = options + row }
    }
    if p.subcommands.len > 0 {
        sub := p.subcommands[0]
        positionals = positionals + help_row(sub.label(), sub.options.help, column, 0)
        for name in sub.names {
            description := sub.descriptions[name]
            if description != '' { positionals = positionals + help_row(name, description, column, 2) }
        }
    }
    if positionals != '' { result = result + 'positional arguments:\n' + positionals + '\n' }
    if options != '' { result = result + 'options:\n' + options + '\n' }
    if p.settings.epilog != '' {
        result = result + wrap_text(replace_text(p.settings.epilog, '%(prog)s', p.prog), 78, '', '') + '\n'
    }
    for result.len > 0 && result[result.len - 1] == 10 { result = result[0 .. result.len - 1] }
    return result + '\n'
}
