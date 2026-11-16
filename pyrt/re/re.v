module re

import regex.pcre
import pyrt

// Python's re facade over the available PCRE wrapper. The supplied Match API
// does NOT expose capture offsets or a capture-count/name table. Those pieces
// are recorded by captures.v for its supported grammar. Unsupported capturing
// grammar is rejected explicitly; native group-free spans remain approximate.
pub const ignorecase = 2
pub const locale = 4
pub const multiline = 8
pub const dotall = 16
pub const unicode = 32
pub const verbose = 64
pub const debug = 128
pub const ascii = 256
pub const noflag = 0
pub const error_class = 're.error'

pub struct Span {
pub:
    start int
    end int
}

pub struct SubResult {
pub:
    text string
    count int
}

pub struct Pattern {
    regex pcre.Regex
    captures CaptureProgram
pub:
    pattern string
    flags int
    group_count int
    group_names map[string]int
}

pub struct Match {
    values []pyrt.Value
    offsets []Span
    group_names map[string]int
    count int
pub:
    source string
    start_byte int
    end_byte int
}

fn register_error() {
    pyrt.register_exception('re.error', ['Exception'])
}

fn regex_error(message string) IError {
    register_error()
    return pyrt.raise('re.error', message)
}

fn flags_prefix(flags int) !string {
    unsupported := flags & (locale | debug | ascii)
    if unsupported != 0 { return pyrt.raise('NotImplementedError', 'LOCALE, ASCII and DEBUG regex flags are not implemented') }
    if flags & ~(ignorecase | multiline | dotall | verbose | unicode | noflag) != 0 {
        return regex_error('invalid flags')
    }
    mut result := ''
    if flags & ignorecase != 0 { result = result + 'i' }
    if flags & multiline != 0 { result = result + 'm' }
    if flags & dotall != 0 { result = result + 's' }
    // VERBOSE is rewritten below instead of relying on the PCRE wrapper's x flag.
    return if result == '' { '' } else { '(?' + result + ')' }
}

// Python re.VERBOSE: discard unescaped ASCII pattern whitespace and # comments
// outside character classes. Escapes are copied as a pair, preserving \\ and \#.
// This handles the module-level flag; scoped inline (?x:...) and (?-x:...)
// have intentionally not been reimplemented.
fn verbose_pattern(pattern string) string {
    mut out := ''
    mut i := 0
    mut in_class := false
    mut class_first := false
    mut in_comment := false
    for i < pattern.len {
        b := pattern[i]
        if in_comment {
            if b == 10 || b == 13 { in_comment = false }
            i = i + 1
            continue
        }
        if b == 92 {
            out = out + pattern[i .. i + 1]
            if i + 1 < pattern.len {
                out = out + pattern[i + 1 .. i + 2]
                i = i + 2
            } else {
                i = i + 1
            }
            if in_class { class_first = false }
            continue
        }
        if in_class {
            out = out + pattern[i .. i + 1]
            // The first ']' (or first after '^') is a literal class member.
            if b == 93 && !class_first { in_class = false }
            if b != 94 || !class_first { class_first = false }
            i = i + 1
            continue
        }
        if b == 91 {
            in_class = true
            class_first = true
            out = out + '['
        } else if b == 35 {
            in_comment = true
        } else if b == 32 || b == 9 || b == 10 || b == 13 || b == 12 || b == 11 {
            // re.VERBOSE ignores these six ASCII whitespace bytes.
        } else {
            out = out + pattern[i .. i + 1]
        }
        i = i + 1
    }
    return out
}

struct GroupMetadata {
    count int
    names map[string]int
}

// Counts conventional and named captures, recognizing common noncapturing
// constructs. Does not parse PCRE DEFINE, branch reset, or (?(...)...) syntax.
fn capture_metadata(pattern string) GroupMetadata {
    mut count := 0
    mut names := map[string]int{}
    mut i := 0
    mut in_class := false
    for i < pattern.len {
        c := pattern[i]
        if c == 92 { i = i + 2; continue }
        if c == 91 { in_class = true; i = i + 1; continue }
        if c == 93 { in_class = false; i = i + 1; continue }
        if in_class || c != 40 { i = i + 1; continue }
        if i + 1 >= pattern.len || pattern[i + 1] != 63 {
            count = count + 1
            i = i + 1
            continue
        }
        if i + 3 < pattern.len && pattern[i + 2] == 80 && pattern[i + 3] == 60 {
            count = count + 1
            mut end := i + 4
            for end < pattern.len && pattern[end] != 62 { end = end + 1 }
            if end < pattern.len { names[pattern[i + 4 .. end]] = count }
            i = i + 1
            continue
        }
        if i + 3 < pattern.len && pattern[i + 2] == 60 && pattern[i + 3] != 61 && pattern[i + 3] != 33 {
            count = count + 1
            mut end := i + 3
            for end < pattern.len && pattern[end] != 62 { end = end + 1 }
            if end < pattern.len { names[pattern[i + 3 .. end]] = count }
        }
        i = i + 1
    }
    return GroupMetadata{count: count, names: names}
}

// The supplied PCRE wrapper may return a compiled object for an incomplete
// capture grammar which our recovery parser subsequently rejects as
// NotImplementedError. A malformed Python pattern is re.error instead.
// This lexical check protects delimiter/escape errors; full regex validation
// remains with pcre.compile. Positions here are Unicode code points.
fn validate_pattern_structure(pattern string) ! {
    mut groups := []int{}
    mut class_at := -1
    mut first_class_member := false
    mut i := 0
    for i < pattern.len {
        b := pattern[i]
        if b == 92 { // escaped character
            if i + 1 >= pattern.len {
                return regex_error('bad escape (end of pattern) at position ${pattern[0 .. i].runes().len}')
            }
            if class_at >= 0 { first_class_member = false }
            i = i + 2
            continue
        }
        if class_at >= 0 {
            if b == 93 && !first_class_member {
                class_at = -1
            } else if b == 94 && first_class_member && i == class_at + 1 {
                // A leading caret negates a class; the first closing bracket
                // after it remains a literal member.
            } else {
                first_class_member = false
            }
            i = i + 1
            continue
        }
        if b == 91 {
            class_at = i
            first_class_member = true
        } else if b == 40 {
            // Python's (?#...) comment group treats internal '(' as text.
            if i + 2 < pattern.len && pattern[i + 1] == 63 && pattern[i + 2] == 35 {
                mut end := i + 3
                for end < pattern.len && pattern[end] != 41 { end = end + 1 }
                if end == pattern.len {
                    return regex_error('missing ), unterminated subpattern at position ${pattern[0 .. i].runes().len}')
                }
                i = end + 1
                continue
            }
            groups << i
        } else if b == 41 {
            if groups.len == 0 {
                return regex_error('unbalanced parenthesis at position ${pattern[0 .. i].runes().len}')
            }
            _ = groups.pop()
        }
        i = i + 1
    }
    if class_at >= 0 {
        return regex_error('unterminated character set at position ${pattern[0 .. class_at].runes().len}')
    }
    if groups.len > 0 {
        start := groups[groups.len - 1]
        return regex_error('missing ), unterminated subpattern at position ${pattern[0 .. start].runes().len}')
    }
}

pub fn compile(pattern string, flags int) !Pattern {
    prefix := flags_prefix(flags)!
    effective := if flags & verbose != 0 { verbose_pattern(pattern) } else { pattern }
    validate_pattern_structure(effective)!
    regex := pcre.compile(prefix + effective) or { return regex_error(err.msg()) }
    recovery := capture_program(effective, prefix, flags)
    metadata := capture_metadata(effective)
    count := if recovery.supported { recovery.count } else { metadata.count }
    if count > 0 && !recovery.supported {
        return pyrt.raise('NotImplementedError', 'capturing pattern uses syntax outside the supported capture-recovery grammar')
    }
    names := if recovery.supported { recovery.names } else { metadata.names }
    return Pattern{regex: regex, captures: recovery, pattern: pattern, flags: flags, group_count: count, group_names: names}
}

// Indexes here are UTF-8 BYTES. Public spans convert them to Python's Unicode
// codepoint offsets. The only available match API returns capture text, not
// the matched positions; duplicate substrings/lookarounds remain ambiguous.
fn find_text(text string, piece string, start int, limit int) int {
    if start < 0 || limit > text.len || limit < start { return -1 }
    if piece == '' { return start }
    if piece.len > limit - start { return -1 }
    for i in start .. limit - piece.len + 1 {
        if text[i .. i + piece.len] == piece { return i }
    }
    return -1
}

fn byte_to_char(text string, pos int) int {
    if pos < 0 { return -1 }
    return text[0 .. pos].runes().len
}

fn make_match(p Pattern, raw pcre.Match, source string, from_byte int) Match {
    full := raw.get(0) or { '' }
    mut begin := find_text(source, full, from_byte, source.len)
    if begin < 0 { begin = from_byte }
    mut values := []pyrt.Value{}
    mut offsets := []Span{}
    for i in 0 .. p.group_count + 1 {
        if value := raw.get(i) {
            values << pyrt.Value(value)
            at := if i == 0 { begin } else { find_text(source, value, begin, begin + full.len) }
            offsets << Span{start: at, end: if at < 0 { -1 } else { at + value.len }}
        } else {
            values << pyrt.none_
            offsets << Span{start: -1, end: -1}
        }
    }
    return Match{values: values, offsets: offsets, group_names: p.group_names.clone(), count: p.group_count,
        source: source, start_byte: begin, end_byte: begin + full.len}
}

pub fn (p Pattern) search(text string) ?Match {
    if p.captures.supported { return p.capture_search(text, 0, false, false, false) }
    original := p.regex.find(text) or { return none }
    return make_match(p, original, text, 0)
}

pub fn (p Pattern) match_(text string) ?Match {
    if p.captures.supported { return p.capture_search(text, 0, true, false, false) }
    original := p.regex.find(text) or { return none }
    result := make_match(p, original, text, 0)
    if result.start_byte != 0 { return none }
    return result
}

pub fn (p Pattern) fullmatch(text string) ?Match {
    if p.captures.supported { return p.capture_search(text, 0, true, true, false) }
    original := p.regex.fullmatch(text) or { return none }
    return make_match(p, original, text, 0)
}

pub fn (p Pattern) finditer(text string) []Match {
    mut result := []Match{}
    mut index := 0
    mut previous_empty := false
    if p.captures.supported {
        for index <= text.len {
            m := p.capture_search(text, index, false, false, previous_empty) or { break }
            result << m
            index = m.end_byte
            previous_empty = m.start_byte == m.end_byte
        }
        return result
    }
    // Native fallback still cannot request a nonempty match at the same
    // position after an empty match. Never advance into the middle of UTF-8.
    for index <= text.len {
        original := p.regex.find_from(text, index) or { break }
        m := make_match(p, original, text, index)
        result << m
        if m.end_byte > index { index = m.end_byte }
        else {
            if index == text.len { break }
            index = next_codepoint(text, index)
        }
    }
    return result
}

pub fn (m Match) group(n int) !pyrt.Value {
    if n < 0 || n > m.count { return pyrt.raise('IndexError', 'no such group') }
    return m.values[n]
}

pub fn (m Match) group_name(name string) !pyrt.Value {
    n := m.group_names[name] or { return pyrt.raise('IndexError', 'no such group') }
    return m.group(n)!
}

pub fn (m Match) groups() []pyrt.Value {
    mut out := []pyrt.Value{}
    for i in 1 .. m.count + 1 { out << (m.group(i) or { pyrt.none_ }) }
    return out
}

pub fn (m Match) groupdict() map[string]pyrt.Value {
    mut out := map[string]pyrt.Value{}
    for name, index in m.group_names { out[name] = m.group(index) or { pyrt.none_ } }
    return out
}

fn (m Match) byte_span(n int) !Span {
    if n < 0 || n > m.count { return pyrt.raise('IndexError', 'no such group') }
    return m.offsets[n]
}

pub fn (m Match) span(n int) !Span {
    s := m.byte_span(n)!
    return Span{start: byte_to_char(m.source, s.start), end: byte_to_char(m.source, s.end)}
}
pub fn (m Match) start(n int) !int { return (m.span(n)!).start }
pub fn (m Match) end(n int) !int { return (m.span(n)!).end }

pub fn search(pattern string, text string, flags int) !pyrt.Maybe[Match] {
    p := compile(pattern, flags)!
    if m := p.search(text) { return pyrt.some(m) }
    return pyrt.nothing[Match]()
}

pub fn match_(pattern string, text string, flags int) !pyrt.Maybe[Match] {
    p := compile(pattern, flags)!
    if m := p.match_(text) { return pyrt.some(m) }
    return pyrt.nothing[Match]()
}

pub fn fullmatch(pattern string, text string, flags int) !pyrt.Maybe[Match] {
    p := compile(pattern, flags)!
    if m := p.fullmatch(text) { return pyrt.some(m) }
    return pyrt.nothing[Match]()
}

pub fn finditer(pattern string, text string, flags int) ![]Match {
    p := compile(pattern, flags)!
    return p.finditer(text)
}

pub fn (p Pattern) findall(text string) []pyrt.Value {
    mut results := []pyrt.Value{}
    for m in p.finditer(text) {
        if p.group_count == 0 {
            results << m.group(0) or { pyrt.Value('') }
        } else if p.group_count == 1 {
            item := m.group(1) or { pyrt.none_ }
            results << if item is string { item } else { pyrt.Value('') }
        } else {
            mut items := []pyrt.Value{}
            for value in m.groups() {
                items << if value is string { value } else { pyrt.Value('') }
            }
            results << pyrt.Value(pyrt.new_tuple(items))
        }
    }
    return results
}

pub fn findall(pattern string, text string, flags int) ![]pyrt.Value {
    p := compile(pattern, flags)!
    return p.findall(text)
}

fn expand_replacement(template string, m Match) !string {
    mut out := ''
    mut i := 0
    for i < template.len {
        if template[i] != 92 {
            out = out + template[i .. i + 1]
            i = i + 1
            continue
        }
        if i + 1 >= template.len { return regex_error('bad escape (end of pattern)') }
        next := template[i + 1]
        if next == 92 { out = out + '\\'; i = i + 2; continue }
        if next == 110 { out = out + '\n'; i = i + 2; continue }
        if next == 114 { out = out + '\r'; i = i + 2; continue }
        if next == 116 { out = out + '\t'; i = i + 2; continue }
        if next == 103 && i + 2 < template.len && template[i + 2] == 60 {
            mut end := i + 3
            for end < template.len && template[end] != 62 { end = end + 1 }
            if end >= template.len { return regex_error('missing >') }
            name := template[i + 3 .. end]
            mut numeric := name.len > 0
            for c in 0 .. name.len { if name[c] < 48 || name[c] > 57 { numeric = false; break } }
            if numeric {
                mut index := 0
                for c in 0 .. name.len { index = index * 10 + int(name[c] - 48) }
                value := m.group(index) or { return regex_error('invalid group reference') }
                if value is string { out = out + value }
            } else {
                value := m.group_name(name) or { return regex_error("unknown group name '${name}'") }
                if value is string { out = out + value }
            }
            i = end + 1
            continue
        }
        if next >= 48 && next <= 57 {
            mut value := int(next - 48)
            mut consumed := 2
            if i + 2 < template.len && template[i + 2] >= 48 && template[i + 2] <= 57 {
                value = value * 10 + int(template[i + 2] - 48)
                consumed = 3
            }
            part := m.group(value) or { return regex_error('invalid group reference') }
            if part is string { out = out + part }
            i = i + consumed
            continue
        }
        // Python 3.7+ errors for unknown ASCII-letter escapes.
        if (next >= 65 && next <= 90) || (next >= 97 && next <= 122) {
            return regex_error('bad escape in replacement')
        }
        out = out + '\\' + template[i + 1 .. i + 2]
        i = i + 2
    }
    return out
}

fn (p Pattern) replace_internal(text string, count int, replacement string, callback fn (m Match) string, use_callback bool) !SubResult {
    mut out := ''
    mut before := 0
    mut replaced := 0
    for m in p.finditer(text) {
        if count > 0 && replaced >= count { break }
        if m.start_byte < before || m.end_byte > text.len { continue }
        out = out + text[before .. m.start_byte]
        out = out + if use_callback { callback(m) } else { expand_replacement(replacement, m)! }
        before = m.end_byte
        replaced = replaced + 1
    }
    out = out + text[before .. text.len]
    return SubResult{text: out, count: replaced}
}

fn unused_callback(_ Match) string { return '' }

pub fn (p Pattern) sub(replacement string, text string, count int) !string {
    return (p.replace_internal(text, count, replacement, unused_callback, false)!).text
}

pub fn (p Pattern) subn(replacement string, text string, count int) !SubResult {
    return p.replace_internal(text, count, replacement, unused_callback, false)!
}

pub fn (p Pattern) sub_callback(callback fn (m Match) string, text string, count int) !string {
    return (p.replace_internal(text, count, '', callback, true)!).text
}

pub fn sub(pattern string, replacement string, text string, count int, flags int) !string {
    p := compile(pattern, flags)!
    return p.sub(replacement, text, count)!
}

pub fn subn(pattern string, replacement string, text string, count int, flags int) !SubResult {
    p := compile(pattern, flags)!
    return p.subn(replacement, text, count)!
}

pub fn (p Pattern) split(text string, maxsplit int) ![]pyrt.Value {
    mut result := []pyrt.Value{}
    mut previous := 0
    mut count := 0
    for m in p.finditer(text) {
        if maxsplit > 0 && count >= maxsplit { break }
        if m.start_byte < previous { continue }
        result << pyrt.Value(text[previous .. m.start_byte])
        for item in m.groups() { result << item }
        previous = m.end_byte
        count = count + 1
    }
    result << pyrt.Value(text[previous .. text.len])
    return result
}

pub fn split(pattern string, text string, maxsplit int, flags int) ![]pyrt.Value {
    p := compile(pattern, flags)!
    return p.split(text, maxsplit)!
}

pub fn escape(text string) string {
    // Exact punctuation table of Python re.escape in recent CPython.
    specials := '\\.^$*+?{}[]|()-#&~ \t\n\r\v\f'
    mut output := ''
    for i in 0 .. text.len {
        c := text[i .. i + 1]
        if specials.contains(c) { output = output + '\\' }
        output = output + c
    }
    return output
}
