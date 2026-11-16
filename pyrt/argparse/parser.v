module argparse

import pyrt
import pyrt.json as pyjson

struct OptionUse {
    index int
    explicit string
    has_explicit bool
}
struct ResolvedOption {
    found bool
    uses []OptionUse
}

fn strip_text(text string) string {
    return pyrt.str(pyrt.call_method(pyrt.Value(text), 'strip', []pyrt.Value{}) or { pyrt.Value(text) })
}
fn ascii_lower(text string) string {
    return pyrt.str(pyrt.call_method(pyrt.Value(text), 'lower', []pyrt.Value{}) or { pyrt.Value(text) })
}

fn decimal_integer(text string) !pyrt.Value {
    raw := strip_text(text)
    if raw == '' { return pyrt.raise('ValueError', 'invalid int') }
    mut i := 0
    mut negative := false
    if raw[0] == 43 || raw[0] == 45 { negative = raw[0] == 45; i = 1 }
    if i == raw.len { return pyrt.raise('ValueError', 'invalid int') }
    // Accumulate negatively so the full signed i64 minimum is representable.
    minimum := i64(-9223372036854775807) - 1
    limit := if negative { minimum } else { -i64(9223372036854775807) }
    mut n := i64(0)
    mut previous_digit := false
    for i < raw.len {
        b := raw[i]
        if b == 95 {
            if !previous_digit || i + 1 >= raw.len || raw[i + 1] < 48 || raw[i + 1] > 57 { return pyrt.raise('ValueError', 'invalid int') }
            previous_digit = false
            i = i + 1
            continue
        }
        if b < 48 || b > 57 { return pyrt.raise('ValueError', 'invalid int') }
        digit := i64(b - 48)
        if n < (limit + digit) / 10 { return pyrt.raise('OverflowError', 'Python int exceeds pyrt i64 range') }
        n = n * 10 - digit
        previous_digit = true
        i = i + 1
    }
    return pyrt.Value(if negative { n } else { -n })
}

fn decimal_float(text string) !pyrt.Value {
    raw := strip_text(text)
    if raw == '' { return pyrt.raise('ValueError', 'invalid float') }
    lower := ascii_lower(raw)
    if lower in ['inf', '+inf', 'infinity', '+infinity'] { return pyjson.loads('Infinity')! }
    if lower in ['-inf', '-infinity'] { return pyjson.loads('-Infinity')! }
    if lower in ['nan', '+nan', '-nan'] { return pyjson.loads('NaN')! }
    mut cleaned := ''
    for i in 0 .. raw.len {
        b := raw[i]
        if b == 95 {
            if i == 0 || i + 1 == raw.len || raw[i - 1] < 48 || raw[i - 1] > 57 || raw[i + 1] < 48 || raw[i + 1] > 57 {
                return pyrt.raise('ValueError', 'invalid float')
            }
        } else { cleaned = cleaned + raw[i .. i + 1] }
    }
    mut i := 0
    mut sign := ''
    if cleaned[0] == 43 || cleaned[0] == 45 {
        if cleaned[0] == 45 { sign = '-' }
        i = 1
    }
    start := i
    for i < cleaned.len && cleaned[i] >= 48 && cleaned[i] <= 57 { i = i + 1 }
    mut whole := cleaned[start .. i]
    mut fraction := ''
    mut has_dot := false
    if i < cleaned.len && cleaned[i] == 46 {
        has_dot = true
        i = i + 1
        fraction_start := i
        for i < cleaned.len && cleaned[i] >= 48 && cleaned[i] <= 57 { i = i + 1 }
        fraction = cleaned[fraction_start .. i]
    }
    if whole == '' && fraction == '' { return pyrt.raise('ValueError', 'invalid float') }
    mut exponent := ''
    if i < cleaned.len && (cleaned[i] == 101 || cleaned[i] == 69) {
        exponent_start := i
        i = i + 1
        if i < cleaned.len && (cleaned[i] == 43 || cleaned[i] == 45) { i = i + 1 }
        digits_start := i
        for i < cleaned.len && cleaned[i] >= 48 && cleaned[i] <= 57 { i = i + 1 }
        if digits_start == i { return pyrt.raise('ValueError', 'invalid float') }
        exponent = cleaned[exponent_start .. i]
    }
    if i != cleaned.len { return pyrt.raise('ValueError', 'invalid float') }
    for whole.len > 1 && whole[0] == 48 { whole = whole[1 .. whole.len] }
    if whole == '' { whole = '0' }
    if fraction == '' { fraction = '0' }
    // Always include the decimal point, preserving -0 as binary64 -0.0.
    _ = has_dot
    value := pyjson.loads(sign + whole + '.' + fraction + exponent)!
    return pyrt.Value(pyrt.as_float(value)!)
}

fn value_type_name(kind ValueType) string {
    return match kind { .str_type { 'str' } .int_type { 'int' } .float_type { 'float' } }
}
fn (a &Argument) label() string { return if a.positional { a.dest } else { a.names.join('/') } }
fn (p &ArgumentParser) convert(a &Argument, text string) !pyrt.Value {
    if a.value_type == .str_type { return pyrt.Value(text) }
    if a.value_type == .int_type {
        return decimal_integer(text) or { return p.failure('argument ${a.label()}: invalid int value: ${pyrt.repr(pyrt.Value(text))}') }
    }
    return decimal_float(text) or { return p.failure('argument ${a.label()}: invalid float value: ${pyrt.repr(pyrt.Value(text))}') }
}
fn (p &ArgumentParser) check_choice(a &Argument, value pyrt.Value) ! {
    if !a.has_choices { return }
    for allowed in a.choices { if pyrt.eq(allowed, value) { return } }
    mut choices := []string{}
    for allowed in a.choices { choices << pyrt.repr(allowed) }
    return p.failure('argument ${a.label()}: invalid choice: ${pyrt.repr(value)} (choose from ${choices.join(", ")})')
}

fn is_negative_number(text string) bool {
    if text.len < 2 || text[0] != 45 { return false }
    mut i := 1
    for i < text.len && text[i] >= 48 && text[i] <= 57 { i = i + 1 }
    if i == text.len { return true }
    if text[i] != 46 { return false }
    i = i + 1
    start := i
    for i < text.len && text[i] >= 48 && text[i] <= 57 { i = i + 1 }
    return i == text.len && i > start
}
fn (p &ArgumentParser) option_like(token string) bool {
    if token == '-' || token.len == 0 || token[0] != 45 { return false }
    if is_negative_number(token) {
        for a in p.arguments {
            if !a.positional { for name in a.names { if is_negative_number(name) { return true } } }
        }
        return false
    }
    // argparse treats a token containing spaces as positional when it is not
    // a registered option. This is relevant to explicit shell-quoted tokens.
    if token.contains(' ') {
        for a in p.arguments { if !a.positional && token in a.names { return true } }
        return false
    }
    return true
}
fn starts_with(text string, prefix string) bool { return text.len >= prefix.len && text[0 .. prefix.len] == prefix }

fn (p &ArgumentParser) resolve_option(token string) !ResolvedOption {
    for i, a in p.arguments {
        if !a.positional && token in a.names { return ResolvedOption{found: true, uses: [OptionUse{index: i}]} }
    }
    mut name := token
    mut explicit := ''
    mut has_explicit := false
    for i in 0 .. token.len {
        if token[i] == 61 { name = token[0 .. i]; explicit = token[i + 1 .. token.len]; has_explicit = true; break }
    }
    if has_explicit {
        for i, a in p.arguments {
            if !a.positional && name in a.names { return ResolvedOption{found: true, uses: [OptionUse{index: i, explicit: explicit, has_explicit: true}]} }
        }
    }
    if name.len > 2 && name[0 .. 2] == '--' {
        if !p.settings.allow_abbrev { return ResolvedOption{} }
        mut candidates := []OptionUse{}
        mut candidate_names := []string{}
        for i, a in p.arguments {
            if a.positional { continue }
            for option in a.names {
                if starts_with(option, name) {
                    candidates << OptionUse{index: i, explicit: explicit, has_explicit: has_explicit}
                    candidate_names << option
                }
            }
        }
        if candidates.len == 1 { return ResolvedOption{found: true, uses: candidates} }
        if candidates.len > 1 { return p.failure('ambiguous option: ${token} could match ${candidate_names.join(", ")}') }
        return ResolvedOption{}
    }
    if token.len <= 2 { return ResolvedOption{} }
    mut uses := []OptionUse{}
    mut at := 1
    for at < token.len {
        short_name := '-' + token[at .. at + 1]
        mut index := -1
        for i, a in p.arguments { if !a.positional && short_name in a.names { index = i; break } }
        if index < 0 {
            if uses.len == 0 { return ResolvedOption{} }
            previous := p.arguments[uses[uses.len - 1].index]
            return p.failure('argument ${previous.label()}: ignored explicit argument ${pyrt.repr(pyrt.Value(token[at .. token.len]))}')
        }
        argument := p.arguments[index]
        at = at + 1
        if !is_zero_argument(argument.action) {
            mut attached := token[at .. token.len]
            if starts_with(attached, '=') { attached = attached[1 .. attached.len] }
            uses << OptionUse{index: index, explicit: attached, has_explicit: at < token.len}
            return ResolvedOption{found: true, uses: uses}
        }
        uses << OptionUse{index: index}
    }
    return ResolvedOption{found: true, uses: uses}
}

fn (p &ArgumentParser) value_for(a &Argument, raw []string, from_option bool) !pyrt.Value {
    if raw.len == 0 && a.nargs == '?' {
        mut result := if from_option { a.constant } else { a.default_value }
        unconverted := result
        if unconverted is string { if unconverted == suppress { return result }; result = p.convert(a, unconverted)! }
        if from_option { p.check_choice(a, result)! }
        return result
    }
    if raw.len == 0 && a.positional && a.nargs == '*' && a.default_value !is pyrt.NoneType {
        return a.default_value
    }
    mut values := []pyrt.Value{}
    for text in raw { value := p.convert(a, text)!; p.check_choice(a, value)!; values << value }
    if a.nargs == '' || a.nargs == '?' {
        if values.len == 0 { return a.default_value }
        return values[0]
    }
    return pyrt.Value(pyrt.new_list(values))
}

fn (p &ArgumentParser) assign(index int, value pyrt.Value, ns &Namespace, mut seen map[string]bool, mut groups map[string]int) ! {
    a := p.arguments[index]
    if a.group_id >= 0 {
        key := a.group_id.str()
        if previous := groups[key] {
            if previous != index { return p.failure('argument ${a.label()}: not allowed with argument ${p.arguments[previous].label()}') }
        }
        groups[key] = index
    }
    seen[index.str()] = true
    if a.dest == suppress { return }
    if value is string { if value == suppress { return } }
    if a.action == 'append' {
        mut items := []pyrt.Value{}
        old := ns.get(a.dest)
        if old is &pyrt.List { items = old.items.clone() }
        else if old !is pyrt.NoneType { return pyrt.raise('AttributeError', "'${pyrt.type_name(old)}' object has no attribute 'append'") }
        items << value
        ns.set(a.dest, pyrt.Value(pyrt.new_list(items)))
    } else if a.action == 'count' {
        previous := ns.get(a.dest)
        n := if previous is pyrt.NoneType { i64(0) } else { pyrt.as_int(previous)! }
        ns.set(a.dest, pyrt.add(pyrt.Value(n), pyrt.Value(i64(1)))!)
    } else { ns.set(a.dest, value) }
}

fn (p &ArgumentParser) consume_options(argv []string, at int, resolved ResolvedOption, ns &Namespace, mut seen map[string]bool, mut groups map[string]int) !int {
    mut next := at + 1
    for use in resolved.uses {
        a := p.arguments[use.index]
        if is_zero_argument(a.action) {
            if use.has_explicit { return p.failure('argument ${a.label()}: ignored explicit argument ${pyrt.repr(pyrt.Value(use.explicit))}') }
            if a.action == 'help' { p.print_help(); return system_exit(0) }
            if a.action == 'version' {
                p.output_text(replace_text(a.version, '%(prog)s', p.prog) + '\n')
                return system_exit(0)
            }
            value := pyrt.Value(a.action == 'store_true')
            p.assign(use.index, value, ns, mut seen, mut groups)!
            continue
        }
        size := nargs_count(a.nargs)!
        mut raw := []string{}
        if use.has_explicit {
            if size > 1 { return p.failure('argument ${a.label()}: expected ${size} arguments') }
            raw << use.explicit
        } else {
            limit := if size >= 0 { size } else if size == -1 { 1 } else { argv.len }
            for next < argv.len && raw.len < limit && !p.option_like(argv[next]) {
                raw << argv[next]
                next = next + 1
            }
            if size > 0 && raw.len < size {
                message := if a.nargs == '' { 'expected one argument' } else { 'expected ${size} ' + if size == 1 { 'argument' } else { 'arguments' } }
                return p.failure('argument ${a.label()}: ${message}')
            }
            if size == -3 && raw.len == 0 { return p.failure('argument ${a.label()}: expected at least one argument') }
        }
        value := p.value_for(a, raw, true)!
        p.assign(use.index, value, ns, mut seen, mut groups)!
    }
    return next
}

fn (p &ArgumentParser) positional_indexes() []int {
    mut out := []int{}
    for i, a in p.arguments { if a.positional { out << i } }
    return out
}
struct PositionalChunk {
    assigned int
    used int
}

fn (p &ArgumentParser) assign_positionals(tokens []string, first int, ns &Namespace, mut seen map[string]bool, mut groups map[string]int) !PositionalChunk {
    positionals := p.positional_indexes()
    // CPython consumes only a contiguous positional run before each option.
    // Find the longest prefix of remaining actions whose minima fit this run;
    // it does not pool values across option boundaries like parse_intermixed_args.
    mut chosen := positionals.len - first
    for chosen > 0 {
        mut minimum := 0
        for j in first .. first + chosen {
            size := nargs_count(p.arguments[positionals[j]].nargs)!
            if size > 0 { minimum = minimum + size }
            else if size == -3 { minimum = minimum + 1 }
        }
        if minimum <= tokens.len { break }
        chosen = chosen - 1
    }
    mut at := 0
    for which in first .. first + chosen {
        index := positionals[which]
        a := p.arguments[index]
        size := nargs_count(a.nargs)!
        mut minimum_after := 0
        for j in which + 1 .. first + chosen {
            later := nargs_count(p.arguments[positionals[j]].nargs)!
            if later > 0 { minimum_after = minimum_after + later }
            else if later == -3 { minimum_after = minimum_after + 1 }
        }
        mut count := size
        if size < 0 {
            count = tokens.len - at - minimum_after
            if size == -1 && count > 1 { count = 1 }
        }
        raw := tokens[at .. at + count].clone()
        at = at + count
        value := p.value_for(a, raw, false)!
        p.assign(index, value, ns, mut seen, mut groups)!
    }
    return PositionalChunk{assigned: chosen, used: at}
}

fn (p &ArgumentParser) initial_namespace() Namespace {
    n := new_namespace(map[string]pyrt.Value{})
    for a in p.arguments {
        if a.dest == suppress || a.action == 'help' || a.action == 'version' { continue }
        default_value := a.default_value
        if default_value is string { if default_value == suppress { continue } }
        if !n.has(a.dest) { n.set(a.dest, default_value) }
    }
    for key, value in p.defaults { if !n.has(key) { n.set(key, value) } }
    if p.subcommands.len > 0 {
        dest := p.subcommands[0].options.dest
        if dest != suppress && !n.has(dest) { n.set(dest, pyrt.none_) }
    }
    return n
}

fn (p &ArgumentParser) finish(ns &Namespace, seen map[string]bool, groups map[string]int, chose_sub bool) ! {
    mut missing := []string{}
    for i, a in p.arguments {
        if i.str() in seen { continue }
        size := if is_zero_argument(a.action) { 0 } else { nargs_count(a.nargs)! }
        if a.required || (a.positional && (size > 0 || size == -3)) { missing << a.label() }
        else if n := ns.values[a.dest] {
            if n is string { if n == suppress { continue }; if pyrt.eq(n, a.default_value) { ns.set(a.dest, p.convert(a, n)!) } }
        }
    }
    if p.subcommands.len > 0 && p.subcommands[0].options.required && !chose_sub {
        subs := p.subcommands[0]
        missing << if subs.options.dest == suppress { subs.label() } else { subs.options.dest }
    }
    if missing.len > 0 { return p.failure('the following arguments are required: ${missing.join(", ")}') }
    for i, group in p.groups {
        if group.required && i.str() !in groups {
            mut labels := []string{}
            for index in group.members { if p.arguments[index].help != suppress { labels << p.arguments[index].label() } }
            return p.failure('one of the arguments ${labels.join(" ")} is required')
        }
    }
}

pub fn (p &ArgumentParser) parse_known_args(argv []string) !ParseKnown {
    unsafe { p.output = ''; p.diagnostics = '' }
    ns := p.initial_namespace()
    mut seen := map[string]bool{}
    mut groups := map[string]int{}
    mut bare := []string{}
    mut bare_positions := []int{}
    mut unknown := []string{}
    mut unknown_positions := []int{}
    mut marker_position := -1
    mut at := 0
    mut ended_options := false
    mut chose_sub := false
    mut positional_at := 0
    for at < argv.len {
        token := argv[at]
        if !ended_options && token == '--' { ended_options = true; marker_position = at; at = at + 1; continue }
        if !ended_options && p.option_like(token) {
            if bare.len > 0 {
                prefix := p.assign_positionals(bare, positional_at, ns, mut seen, mut groups)!
                positional_at = positional_at + prefix.assigned
                for j in prefix.used .. bare.len { unknown << bare[j]; unknown_positions << bare_positions[j] }
                bare = []string{}
                bare_positions = []int{}
            }
            resolved := p.resolve_option(token)!
            if resolved.found { at = p.consume_options(argv, at, resolved, ns, mut seen, mut groups)! }
            else { unknown << token; unknown_positions << at; at = at + 1 }
            continue
        }
        mut needed_before_sub := 0
        if p.subcommands.len > 0 {
            indexes := p.positional_indexes()
            for j in positional_at .. indexes.len { needed_before_sub = needed_before_sub + nargs_count(p.arguments[indexes[j]].nargs)! }
        }
        if p.subcommands.len > 0 && bare.len >= needed_before_sub {
            before_command := p.assign_positionals(bare, positional_at, ns, mut seen, mut groups)!
            positional_at = positional_at + before_command.assigned
            bare = []string{}
            bare_positions = []int{}
            subs := p.subcommands[0]
            child := subs.parsers[token] or {
                mut allowed := []string{}
                for name in subs.names { allowed << pyrt.repr(pyrt.Value(name)) }
                label := if subs.options.dest != suppress { subs.options.dest } else { subs.label() }
                return p.failure('argument ${label}: invalid choice: ${pyrt.repr(pyrt.Value(token))} (choose from ${allowed.join(", ")})')
            }
            if subs.options.dest != suppress { ns.set(subs.options.dest, pyrt.Value(token)) }
            parsed := child.parse_known_args(argv[at + 1 .. argv.len]) or {
                unsafe { p.output = p.output + child.output; p.diagnostics = p.diagnostics + child.diagnostics }
                return err
            }
            for key, value in parsed.namespace.values { ns.set(key, value) }
            unknown << parsed.unknown
            for location in parsed.unknown_positions { unknown_positions << at + 1 + location }
            chose_sub = true
            break
        }
        bare << token
        bare_positions << at
        at = at + 1
    }
    final_chunk := p.assign_positionals(bare, positional_at, ns, mut seen, mut groups)!
    for j in final_chunk.used .. bare.len { unknown << bare[j]; unknown_positions << bare_positions[j] }
    if marker_position >= 0 && p.positional_indexes().len == 0 && p.subcommands.len == 0 {
        unknown << '--'
        unknown_positions << marker_position
    }
    p.finish(ns, seen, groups, chose_sub)!
    mut ordered := []string{}
    mut locations := []int{}
    for j in 0 .. argv.len {
        for k, original in unknown_positions {
            if original == j { ordered << unknown[k]; locations << j }
        }
    }
    return ParseKnown{namespace: ns, unknown: ordered, unknown_positions: locations}
}

pub fn (p &ArgumentParser) parse_args(argv []string) !Namespace {
    result := p.parse_known_args(argv)!
    if result.unknown.len > 0 { return p.failure('unrecognized arguments: ${result.unknown.join(" ")}') }
    return result.namespace
}
