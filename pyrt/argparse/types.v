module argparse

import os
import pyrt

pub const suppress = '==SUPPRESS=='
pub const argument_error = 'argparse.ArgumentError'

pub enum ValueType {
    str_type
    int_type
    float_type
}

@[params]
pub struct ParserOptions {
pub:
    prog string
    usage string
    description string
    epilog string
    add_help bool = true
    allow_abbrev bool = true
    help string
    // Runtime-only test/embedding switch; parsing still raises SystemExit.
    emit_output bool = true
}

@[params]
pub struct ArgumentOptions {
pub:
    action string = 'store'
    dest string
    value_type ValueType = .str_type
    default_value ?pyrt.Value
    nargs string
    choices []pyrt.Value
    choices_given bool
    required bool
    help string
    metavar string
    const_value ?pyrt.Value
    version string
}

@[params]
pub struct SubparsersOptions {
pub:
    dest string = suppress
    required bool
    help string
    metavar string
}

@[params]
pub struct GroupOptions {
pub:
    required bool
}

pub struct Argument {
pub:
    names []string
    dest string
    action string
    value_type ValueType
    nargs string
    choices []pyrt.Value
    has_choices bool
    required bool
    help string
    metavar string
    constant pyrt.Value
    version string
    positional bool
    group_id int = -1
mut:
    default_value pyrt.Value = pyrt.none_
}

struct GroupState {
    required bool
mut:
    members []int
}

pub struct ArgumentParser {
    settings ParserOptions
    identity i64
pub:
    prog string
mut:
    arguments []&Argument
    defaults map[string]pyrt.Value
    groups []GroupState
    subcommands []&Subparsers
    output string
    diagnostics string
}

pub struct Namespace {
    identity i64
pub mut:
    values map[string]pyrt.Value
}

pub struct ParseKnown {
pub:
    namespace Namespace
    unknown []string
    unknown_positions []int
}

pub struct Subparsers {
    parent &ArgumentParser
    options SubparsersOptions
mut:
    names []string
    parsers map[string]&ArgumentParser
    descriptions map[string]string
}

pub struct MutuallyExclusiveGroup {
    parser &ArgumentParser
    group_id int
}

pub fn new_namespace(values map[string]pyrt.Value) Namespace {
    return Namespace{identity: pyrt.identity_token(), values: values.clone()}
}
pub fn (n &Namespace) has(name string) bool { return name in n.values }
pub fn (n &Namespace) get(name string) pyrt.Value { return n.values[name] or { pyrt.none_ } }
pub fn (n &Namespace) require(name string) !pyrt.Value {
    return n.values[name] or { return pyrt.raise('AttributeError', "'Namespace' object has no attribute '${name}'") }
}
pub fn (n &Namespace) get_str(name string) !string { return pyrt.as_str(n.require(name)!)! }
pub fn (n &Namespace) get_int(name string) !i64 { return pyrt.as_int(n.require(name)!)! }
pub fn (n &Namespace) get_float(name string) !f64 { return pyrt.as_float(n.require(name)!)! }
pub fn (n &Namespace) get_bool(name string) !bool { return pyrt.as_bool(n.require(name)!)! }
pub fn (n &Namespace) get_strings(name string) ![]string { return pyrt.as_strings(n.require(name)!)! }
pub fn (n &Namespace) set(name string, value pyrt.Value) { unsafe { n.values[name] = value } }
pub fn (n &Namespace) class_name() string { return 'Namespace' }
pub fn (n &Namespace) pyrt_identity() i64 { return n.identity }
pub fn (n &Namespace) getattr(name string) !pyrt.Value { return n.require(name)! }
pub fn (mut n Namespace) setattr(name string, value pyrt.Value) ! { n.values[name] = value }
pub fn (n &Namespace) as_value() pyrt.Value { return pyrt.Value(pyrt.Instance(n)) }

fn setup_error(message string) IError {
    pyrt.register_exception(argument_error, ['Exception'])
    return pyrt.raise(argument_error, message)
}

fn replace_text(text string, old string, replacement string) string {
    mut out := ''
    mut i := 0
    for i < text.len {
        if old.len > 0 && i + old.len <= text.len && text[i .. i + old.len] == old {
            out = out + replacement
            i = i + old.len
        } else { out = out + text[i .. i + 1]; i = i + 1 }
    }
    return out
}

fn upper(text string) string {
    return pyrt.str(pyrt.call_method(pyrt.Value(text), 'upper', []pyrt.Value{}) or { pyrt.Value(text) })
}

pub fn new_parser(opts ParserOptions) &ArgumentParser {
    mut prog := opts.prog
    if prog == '' { prog = if os.args.len > 0 { os.base(os.args[0]) } else { '-' } }
    p := &ArgumentParser{settings: opts, prog: prog, identity: pyrt.identity_token(), defaults: map[string]pyrt.Value{}}
    if opts.add_help {
        p.add_argument(['-h', '--help'], action: 'help', help: 'show this help message and exit') or { panic(err.msg()) }
    }
    return p
}

fn is_option_name(name string) bool { return name.len > 1 && name[0] == 45 }
fn is_zero_argument(action string) bool { return action in ['store_true', 'store_false', 'count', 'help', 'version'] }

fn nargs_count(nargs string) !int {
    if nargs == '' { return 1 }
    if nargs == '?' { return -1 }
    if nargs == '*' { return -2 }
    if nargs == '+' { return -3 }
    mut count := 0
    if nargs.len == 0 { return pyrt.raise('ValueError', 'invalid nargs value') }
    for i in 0 .. nargs.len {
        b := nargs[i]
        if b < 48 || b > 57 || count > 1000000 { return pyrt.raise('ValueError', 'invalid nargs value') }
        count = count * 10 + int(b - 48)
    }
    if count <= 0 { return pyrt.raise('ValueError', 'nargs for store actions must be != 0; if you have nothing to store, actions such as store true or store const may be more appropriate') }
    return count
}

pub fn (p &ArgumentParser) add_argument(names []string, opts ArgumentOptions) !&Argument {
    return p.add_internal(names, opts, -1)!
}

fn (p &ArgumentParser) add_internal(names []string, opts ArgumentOptions, group_id int) !&Argument {
    if names.len == 0 { return pyrt.raise('TypeError', 'add_argument requires at least one argument name') }
    positional := !is_option_name(names[0])
    if opts.action !in ['store', 'store_true', 'store_false', 'append', 'count', 'version', 'help'] {
        return pyrt.raise('ValueError', "unknown action '${opts.action}'")
    }
    if positional && names.len != 1 { return pyrt.raise('TypeError', 'a positional argument must have one name') }
    if positional && opts.dest != '' { return pyrt.raise('ValueError', 'dest supplied twice for positional argument') }
    if positional && opts.required { return pyrt.raise('TypeError', "'required' is an invalid argument for positionals") }
    if positional && is_zero_argument(opts.action) { return pyrt.raise('NotImplementedError', 'zero-argument positional actions are not supported') }
    if positional && group_id >= 0 { return pyrt.raise('NotImplementedError', 'positional arguments in mutually exclusive groups are not supported') }
    if positional && p.subcommands.len > 0 { return pyrt.raise('NotImplementedError', 'positional arguments following subparsers are not supported') }
    if !is_zero_argument(opts.action) { _ = nargs_count(opts.nargs)! }
    else if opts.nargs != '' { return pyrt.raise('TypeError', 'nargs is not supported by this action') }
    for name in names {
        if !positional && !is_option_name(name) { return pyrt.raise('ValueError', "invalid option string '${name}': must start with a character '-'") }
        for existing in p.arguments {
            if !existing.positional && name in existing.names {
                label := names.join('/')
                return setup_error('argument ${label}: conflicting option string: ${name}')
            }
        }
    }
    mut dest := opts.dest
    if dest == '' {
        dest = names[0]
        if !positional {
            for name in names { if name.len > 2 && name[0 .. 2] == '--' { dest = name; break } }
            mut start := 0
            for start < dest.len && dest[start] == 45 { start = start + 1 }
            dest = replace_text(dest[start .. dest.len], '-', '_')
        }
    }
    mut fallback := p.defaults[dest] or { pyrt.none_ }
    if dest !in p.defaults {
        if opts.action == 'store_true' { fallback = pyrt.Value(false) }
        if opts.action == 'store_false' { fallback = pyrt.Value(true) }
    }
    if given := opts.default_value { fallback = given }
    constant := opts.const_value or { pyrt.none_ }
    arg := &Argument{names: names.clone(), dest: dest, action: opts.action, value_type: opts.value_type,
        default_value: fallback, nargs: opts.nargs, choices: opts.choices.clone(), has_choices: opts.choices_given || opts.choices.len > 0, required: opts.required,
        help: opts.help, metavar: opts.metavar, constant: constant, version: opts.version,
        positional: positional, group_id: group_id}
    unsafe {
        p.arguments << arg
        if group_id >= 0 { p.groups[group_id].members << p.arguments.len - 1 }
    }
    return arg
}

pub fn (p &ArgumentParser) set_defaults(values map[string]pyrt.Value) {
    for name, value in values {
        unsafe { p.defaults[name] = value }
        for argument in p.arguments { if argument.dest == name { unsafe { argument.default_value = value } } }
    }
}

pub fn (p &ArgumentParser) get_default(name string) pyrt.Value {
    for argument in p.arguments { if argument.dest == name { return argument.default_value } }
    return p.defaults[name] or { pyrt.none_ }
}

pub fn (p &ArgumentParser) add_mutually_exclusive_group(opts GroupOptions) &MutuallyExclusiveGroup {
    id := p.groups.len
    unsafe { p.groups << GroupState{required: opts.required} }
    return &MutuallyExclusiveGroup{parser: p, group_id: id}
}
pub fn (g &MutuallyExclusiveGroup) add_argument(names []string, opts ArgumentOptions) !&Argument {
    if opts.required { return pyrt.raise('ValueError', 'mutually exclusive arguments must be optional') }
    return g.parser.add_internal(names, opts, g.group_id)!
}

pub fn (p &ArgumentParser) add_subparsers(opts SubparsersOptions) !&Subparsers {
    if p.subcommands.len > 0 { return setup_error('cannot have multiple subparser arguments') }
    for argument in p.arguments {
        if argument.positional && argument.nargs in ['?', '*', '+'] {
            return pyrt.raise('NotImplementedError', 'subparsers after variable-length positionals are not supported')
        }
    }
    subs := &Subparsers{parent: p, options: opts, parsers: map[string]&ArgumentParser{}, descriptions: map[string]string{}}
    unsafe { p.subcommands << subs }
    return subs
}

pub fn (s &Subparsers) add_parser(name string, opts ParserOptions) !&ArgumentParser {
    if name in s.parsers { return setup_error('argument ${s.label()}: conflicting subparser: ${name}') }
    child := new_parser(ParserOptions{prog: if opts.prog == '' { s.parent.prog + ' ' + name } else { opts.prog },
        usage: opts.usage, description: opts.description, epilog: opts.epilog, add_help: opts.add_help,
        allow_abbrev: opts.allow_abbrev, help: opts.help, emit_output: s.parent.settings.emit_output && opts.emit_output})
    unsafe { s.names << name; s.parsers[name] = child; s.descriptions[name] = opts.help }
    return child
}

fn (s &Subparsers) label() string {
    if s.options.metavar != '' { return s.options.metavar }
    return '{' + s.names.join(',') + '}'
}

pub fn (p &ArgumentParser) last_stdout() string { return p.output }
pub fn (p &ArgumentParser) last_stderr() string { return p.diagnostics }

fn without_final_newline(s string) string {
    if s.len > 0 && s[s.len - 1] == 10 { return s[0 .. s.len - 1] }
    return s
}
fn (p &ArgumentParser) output_text(s string) {
    unsafe { p.output = p.output + s }
    if p.settings.emit_output { print(s) }
}
fn (p &ArgumentParser) diagnostic_text(s string) {
    unsafe { p.diagnostics = p.diagnostics + s }
    // eprintln is the V builtin named in the user's Round 3 reserved-name
    // list; no function called eprintln is defined by this runtime.
    if p.settings.emit_output { eprintln(without_final_newline(s)) }
}
fn system_exit(code int) IError { return IError(pyrt.exception('SystemExit', [pyrt.Value(i64(code))])) }
fn (p &ArgumentParser) failure(message string) IError {
    p.diagnostic_text(p.format_usage() + p.prog + ': error: ' + message + '\n')
    return system_exit(2)
}
pub fn (p &ArgumentParser) error_(message string) ! { return p.failure(message) }
pub fn (p &ArgumentParser) print_help() { p.output_text(p.format_help()) }
pub fn (p &ArgumentParser) print_usage() { p.output_text(p.format_usage()) }
