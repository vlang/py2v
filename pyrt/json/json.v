module json

import pyrt
import os

// A class-name token for pyrt.caught; not a Python exception class value.
pub const json_decode_error = 'JSONDecodeError'

// Python json-compatible public API. This module deliberately never passes
// through json2.Any: the integer/float distinction and dict insertion order
// are retained in pyrt.Value.
@[params]
pub struct DumpOptions {
pub:
    indent       ?int
    sort_keys    bool
    ensure_ascii bool = true
    separators   []string
    default_str  bool
    allow_nan    bool = true
}

fn json_error(kind string, _ string, source string, pos int) IError {
    pyrt.register_exception('JSONDecodeError', ['ValueError'])
    mut line := 1
    mut column := 1
    mut characters := 0
    n := if pos < source.len { pos } else { source.len }
    // CPython counts Unicode code points, not UTF-8 bytes, in positions.
    for i in 0 .. n {
        b := source[i]
        if b >= 128 && b < 192 { continue }
        characters = characters + 1
        if b == 10 { line = line + 1; column = 1 }
        else { column = column + 1 }
    }
    return pyrt.raise('JSONDecodeError', '${kind}: line ${line} column ${column} (char ${characters})')
}

struct Parser {
    source string
mut:
    pos int
}

fn (mut p Parser) whitespace() {
    for p.pos < p.source.len {
        b := p.source[p.pos]
        if b != 32 && b != 9 && b != 10 && b != 13 { break }
        p.pos = p.pos + 1
    }
}

fn (mut p Parser) literal(word string) bool {
    if p.pos + word.len > p.source.len { return false }
    if p.source[p.pos .. p.pos + word.len] != word { return false }
    p.pos = p.pos + word.len
    return true
}

fn hex_digit(b u8) int {
    if b >= 48 && b <= 57 { return int(b) - 48 }
    if b >= 65 && b <= 70 { return int(b) - 55 }
    if b >= 97 && b <= 102 { return int(b) - 87 }
    return -1
}

fn (mut p Parser) unicode_escape() !int {
    if p.pos + 4 > p.source.len {
        return json_error('Invalid \\uXXXX escape', '', p.source, p.pos - 2)
    }
    mut cp := 0
    for i in 0 .. 4 {
        digit := hex_digit(p.source[p.pos + i])
        if digit < 0 { return json_error('Invalid \\uXXXX escape', '', p.source, p.pos - 2) }
        cp = cp * 16 + digit
    }
    p.pos = p.pos + 4
    return cp
}

// rune.str() converts one Unicode scalar or surrogate code point to UTF-8.
// It is a builtin conversion assumption, not a vlib-module call. This and
// the UTF-8 handling of unpaired surrogates require a compiler test.
fn codepoint_string(cp int) string {
    if cp < 128 { return ascii_chars[cp .. cp + 1] }
    return rune(cp).str()
}

const ascii_chars = '\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7f'

fn (mut p Parser) string_value() !string {
    if p.pos >= p.source.len || p.source[p.pos] != 34 {
        return json_error('Expecting value', '', p.source, p.pos)
    }
    quote_start := p.pos
    p.pos = p.pos + 1
    mut output := ''
    mut run_start := p.pos
    for p.pos < p.source.len {
        b := p.source[p.pos]
        if b == 34 {
            output = output + p.source[run_start .. p.pos]
            p.pos = p.pos + 1
            return output
        }
        if b < 32 { return json_error('Invalid control character at', '', p.source, p.pos) }
        if b != 92 { p.pos = p.pos + 1; continue }
        output = output + p.source[run_start .. p.pos]
        p.pos = p.pos + 1
        if p.pos >= p.source.len { return json_error('Unterminated string starting at', '', p.source, quote_start) }
        escaped := p.source[p.pos]
        p.pos = p.pos + 1
        match escaped {
            34 { output = output + '"' }
            92 { output = output + '\\' }
            47 { output = output + '/' }
            98 { output = output + '\x08' }
            102 { output = output + '\x0c' }
            110 { output = output + '\n' }
            114 { output = output + '\r' }
            116 { output = output + '\t' }
            117 {
                mut cp := p.unicode_escape()!
                if cp >= 0xd800 && cp <= 0xdbff && p.pos + 6 <= p.source.len {
                    if p.source[p.pos] == 92 && p.source[p.pos + 1] == 117 {
                        saved := p.pos
                        p.pos = p.pos + 2
                        next := p.unicode_escape() or {
                            p.pos = saved
                            -1
                        }
                        if next >= 0xdc00 && next <= 0xdfff {
                            cp = 0x10000 + (cp - 0xd800) * 1024 + next - 0xdc00
                        } else {
                            p.pos = saved
                        }
                    }
                }
                output = output + codepoint_string(cp)
            }
            else { return json_error('Invalid \\escape', '', p.source, p.pos - 2) }
        }
        run_start = p.pos
    }
    return json_error('Unterminated string starting at', '', p.source, quote_start)
}

fn decimal_int(text string) !i64 {
    negative := text.len > 0 && text[0] == 45
    mut i := if negative { 1 } else { 0 }
    mut value := i64(0)
    min_val := i64(-9223372036854775807) - 1
    for i < text.len {
        digit := i64(text[i] - 48)
        if value < (min_val + digit) / 10 {
            return pyrt.raise('OverflowError', 'JSON integer exceeds signed 64-bit runtime range')
        }
        value = value * 10 - digit
        i = i + 1
    }
    if negative { return value }
    if value == min_val { return pyrt.raise('OverflowError', 'JSON integer exceeds signed 64-bit runtime range') }
    return -value
}

// Exact base-10 to IEEE-754 binary64 conversion. The small private limb
// operations reuse the algorithms already established in core/format.v.
// No C strtod, V float-parsing builtin, or json2 conversion is involved.
const dec_limb_base = i64(1000000000)

fn dec_big_trim(a []i64) []i64 {
    mut result := a.clone()
    for result.len > 1 && result.last() == 0 { _ = result.pop() }
    return result
}

fn dec_big_mul(a []i64, factor i64) []i64 {
    mut out := []i64{}
    mut carry := i64(0)
    for n in a {
        value := n * factor + carry
        out << value % dec_limb_base
        carry = value / dec_limb_base
    }
    for carry > 0 {
        out << carry % dec_limb_base
        carry = carry / dec_limb_base
    }
    return dec_big_trim(out)
}

fn dec_big_add_digit(a []i64, digit i64) []i64 {
    mut out := a.clone()
    mut carry := digit
    mut i := 0
    for carry > 0 && i < out.len {
        value := out[i] + carry
        out[i] = value % dec_limb_base
        carry = value / dec_limb_base
        i = i + 1
    }
    if carry != 0 { out << carry }
    return out
}

fn dec_big_compare(a []i64, b []i64) int {
    if a.len < b.len { return -1 }
    if a.len > b.len { return 1 }
    mut i := a.len - 1
    for i >= 0 {
        if a[i] < b[i] { return -1 }
        if a[i] > b[i] { return 1 }
        i = i - 1
    }
    return 0
}

// Precondition: a >= b.
fn dec_big_subtract(a []i64, b []i64) []i64 {
    mut out := []i64{}
    mut borrow := i64(0)
    for i in 0 .. a.len {
        other := if i < b.len { b[i] } else { i64(0) }
        mut diff := a[i] - other - borrow
        borrow = 0
        if diff < 0 { diff = diff + dec_limb_base; borrow = 1 }
        out << diff
    }
    return dec_big_trim(out)
}

fn dec_big_digits(text string) []i64 {
    mut number := [i64(0)]
    for i in 0 .. text.len {
        number = dec_big_mul(number, 10)
        number = dec_big_add_digit(number, i64(text[i] - 48))
    }
    return number
}

// To nearest representable binary64, ties to even. Integer division is done
// bit by bit on arbitrary-precision nonnegative numerators and denominators.
fn dec_ratio_binary(numerator []i64, denominator []i64) f64 {
    mut top := numerator.clone()
    mut bottom := denominator.clone()
    mut exponent := 0
    for dec_big_compare(top, bottom) < 0 {
        top = dec_big_mul(top, 2)
        exponent = exponent - 1
    }
    for dec_big_compare(top, dec_big_mul(bottom, 2)) >= 0 {
        bottom = dec_big_mul(bottom, 2)
        exponent = exponent + 1
    }
    if exponent > 1023 { return json_infinity() }
    if exponent < -1075 { return 0.0 }
    if exponent == -1075 {
        return if dec_big_compare(top, bottom) > 0 { json_smallest_subnormal() } else { 0.0 }
    }
    mut bits := 52
    mut binary_power := exponent - 52
    if exponent < -1022 {
        bits = exponent + 1074
        binary_power = -1074
    }
    mut mantissa := i64(1)
    mut rest := dec_big_subtract(top, bottom)
    for _ in 0 .. bits {
        rest = dec_big_mul(rest, 2)
        mantissa = mantissa * 2
        if dec_big_compare(rest, bottom) >= 0 {
            rest = dec_big_subtract(rest, bottom)
            mantissa = mantissa + 1
        }
    }
    relation := dec_big_compare(dec_big_mul(rest, 2), bottom)
    if relation > 0 || (relation == 0 && mantissa % 2 != 0) {
        mantissa = mantissa + 1
    }
    if exponent >= -1022 && mantissa == i64(9007199254740992) {
        mantissa = i64(4503599627370496)
        binary_power = binary_power + 1
    }
    mut value := f64(mantissa)
    for binary_power > 0 {
        value = value * 2.0
        binary_power = binary_power - 1
    }
    for binary_power < 0 {
        value = value * 0.5
        binary_power = binary_power + 1
    }
    return value
}

fn json_smallest_subnormal() f64 {
    mut out := 1.0
    for _ in 0 .. 1074 { out = out * 0.5 }
    return out
}

fn decimal_float(text string) f64 {
    negative := text.len > 0 && text[0] == 45
    mut digits := ''
    mut fraction := false
    mut fraction_digits := 0
    mut exponent_at := text.len
    mut i := if negative { 1 } else { 0 }
    for i < text.len {
        byte := text[i]
        if byte == 101 || byte == 69 { exponent_at = i; break }
        if byte == 46 { fraction = true }
        else {
            digits = digits + text[i .. i + 1]
            if fraction { fraction_digits = fraction_digits + 1 }
        }
        i = i + 1
    }
    mut exponent_ten := -fraction_digits
    if exponent_at < text.len {
        mut pos := exponent_at + 1
        mut exp_negative := false
        if pos < text.len && text[pos] == 45 { exp_negative = true; pos = pos + 1 }
        else if pos < text.len && text[pos] == 43 { pos = pos + 1 }
        mut magnitude := 0
        for pos < text.len {
            if magnitude < 100000 { magnitude = magnitude * 10 + int(text[pos]) - 48 }
            pos = pos + 1
        }
        if exp_negative { exponent_ten = exponent_ten - magnitude }
        else { exponent_ten = exponent_ten + magnitude }
    }
    mut start := 0
    for start < digits.len && digits[start] == 48 { start = start + 1 }
    if start == digits.len { return if negative { -0.0 } else { 0.0 } }
    mut end := digits.len
    for end > start && digits[end - 1] == 48 {
        end = end - 1
        exponent_ten = exponent_ten + 1
    }
    digits = digits[start .. end]
    adjusted := exponent_ten + digits.len - 1
    if adjusted > 308 { return if negative { -json_infinity() } else { json_infinity() } }
    if adjusted < -324 { return if negative { -0.0 } else { 0.0 } }
    mut numerator := dec_big_digits(digits)
    mut denominator := [i64(1)]
    if exponent_ten > 0 {
        for _ in 0 .. exponent_ten { numerator = dec_big_mul(numerator, 10) }
    } else if exponent_ten < 0 {
        for _ in 0 .. -exponent_ten { denominator = dec_big_mul(denominator, 10) }
    }
    result := dec_ratio_binary(numerator, denominator)
    return if negative { -result } else { result }
}

fn json_infinity() f64 {
    largest := 1.7976931348623157e308
    return largest + largest
}

fn json_nan() f64 {
    inf := json_infinity()
    return inf - inf
}

fn (mut p Parser) number() !pyrt.Value {
    start := p.pos
    if p.source[p.pos] == 45 { p.pos = p.pos + 1 }
    if p.pos >= p.source.len { return json_error('Expecting value', '', p.source, start) }
    if p.source[p.pos] == 48 {
        p.pos = p.pos + 1
    } else {
        if p.source[p.pos] < 49 || p.source[p.pos] > 57 { return json_error('Expecting value', '', p.source, start) }
        for p.pos < p.source.len && p.source[p.pos] >= 48 && p.source[p.pos] <= 57 { p.pos = p.pos + 1 }
    }
    mut floating := false
    if p.pos + 1 < p.source.len && p.source[p.pos] == 46 && p.source[p.pos + 1] >= 48 && p.source[p.pos + 1] <= 57 {
        floating = true
        p.pos = p.pos + 1
        for p.pos < p.source.len && p.source[p.pos] >= 48 && p.source[p.pos] <= 57 { p.pos = p.pos + 1 }
    }
    if p.pos < p.source.len && (p.source[p.pos] == 101 || p.source[p.pos] == 69) {
        mut exponent_at := p.pos + 1
        if exponent_at < p.source.len && (p.source[exponent_at] == 43 || p.source[exponent_at] == 45) { exponent_at = exponent_at + 1 }
        if exponent_at < p.source.len && p.source[exponent_at] >= 48 && p.source[exponent_at] <= 57 {
            floating = true
            p.pos = exponent_at
            for p.pos < p.source.len && p.source[p.pos] >= 48 && p.source[p.pos] <= 57 { p.pos = p.pos + 1 }
        }
    }
    token := p.source[start .. p.pos]
    if floating { return pyrt.Value(decimal_float(token)) }
    return pyrt.Value(decimal_int(token)!)
}

fn (mut p Parser) value(depth int) !pyrt.Value {
    if depth > 256 { return pyrt.raise('RecursionError', 'maximum recursion depth exceeded while decoding JSON') }
    p.whitespace()
    if p.pos >= p.source.len { return json_error('Expecting value', '', p.source, p.pos) }
    b := p.source[p.pos]
    if b == 34 { return pyrt.Value(p.string_value()!) }
    if p.literal('-Infinity') { return pyrt.Value(-json_infinity()) }
    if b == 45 || (b >= 48 && b <= 57) { return p.number()! }
    if p.literal('true') { return pyrt.Value(true) }
    if p.literal('false') { return pyrt.Value(false) }
    if p.literal('null') { return pyrt.none_ }
    if p.literal('NaN') { return pyrt.Value(json_nan()) }
    if p.literal('Infinity') { return pyrt.Value(json_infinity()) }
    if b == 91 {
        p.pos = p.pos + 1
        p.whitespace()
        mut items := []pyrt.Value{}
        if p.pos < p.source.len && p.source[p.pos] == 93 { p.pos = p.pos + 1; return pyrt.Value(pyrt.new_list(items)) }
        for {
            items << p.value(depth + 1)!
            p.whitespace()
            if p.pos >= p.source.len { return json_error("Expecting ',' delimiter", '', p.source, p.pos) }
            if p.source[p.pos] == 93 { p.pos = p.pos + 1; return pyrt.Value(pyrt.new_list(items)) }
            if p.source[p.pos] != 44 { return json_error("Expecting ',' delimiter", '', p.source, p.pos) }
            comma_pos := p.pos
            p.pos = p.pos + 1
            p.whitespace()
            if p.pos < p.source.len && p.source[p.pos] == 93 {
                return json_error('Illegal trailing comma before end of array', '', p.source, comma_pos)
            }
        }
    }
    if b == 123 {
        p.pos = p.pos + 1
        p.whitespace()
        result := pyrt.Value(pyrt.new_dict())
        if p.pos < p.source.len && p.source[p.pos] == 125 { p.pos = p.pos + 1; return result }
        for {
            p.whitespace()
            if p.pos >= p.source.len || p.source[p.pos] != 34 { return json_error('Expecting property name enclosed in double quotes', '', p.source, p.pos) }
            key := p.string_value()!
            p.whitespace()
            if p.pos >= p.source.len || p.source[p.pos] != 58 { return json_error("Expecting ':' delimiter", '', p.source, p.pos) }
            p.pos = p.pos + 1
            value := p.value(depth + 1)!
            pyrt.setitem(result, pyrt.Value(key), value)!
            p.whitespace()
            if p.pos >= p.source.len { return json_error("Expecting ',' delimiter", '', p.source, p.pos) }
            if p.source[p.pos] == 125 { p.pos = p.pos + 1; return result }
            if p.source[p.pos] != 44 { return json_error("Expecting ',' delimiter", '', p.source, p.pos) }
            comma_pos := p.pos
            p.pos = p.pos + 1
            p.whitespace()
            if p.pos < p.source.len && p.source[p.pos] == 125 {
                return json_error('Illegal trailing comma before end of object', '', p.source, comma_pos)
            }
        }
    }
    return json_error('Expecting value', '', p.source, p.pos)
}

pub fn loads(text string) !pyrt.Value {
    mut p := Parser{source: text}
    p.whitespace()
    value := p.value(0)!
    p.whitespace()
    if p.pos != text.len { return json_error('Extra data', '', text, p.pos) }
    return value
}

pub fn load(path string) !pyrt.Value {
    text := os.read_file(path) or { return pyrt.raise('FileNotFoundError', err.msg()) }
    return loads(text)!
}

fn utf8_point(s string, start int) (int, int) {
    b := int(s[start])
    if b < 128 { return b, 1 }
    if b < 224 && start + 1 < s.len { return (b - 192) * 64 + int(s[start + 1]) - 128, 2 }
    if b < 240 && start + 2 < s.len {
        return (b - 224) * 4096 + (int(s[start + 1]) - 128) * 64 + int(s[start + 2]) - 128, 3
    }
    if start + 3 < s.len {
        return (b - 240) * 262144 + (int(s[start + 1]) - 128) * 4096 + (int(s[start + 2]) - 128) * 64 + int(s[start + 3]) - 128, 4
    }
    return b, 1
}

fn hex4(v int) string {
    chars := '0123456789abcdef'
    mut n := v
    mut s := ''
    for _ in 0 .. 4 {
        digit := n % 16
        s = chars[digit .. digit + 1] + s
        n = n / 16
    }
    return s
}

fn quote_json(text string, ensure_ascii bool) string {
    mut out := '"'
    mut i := 0
    for i < text.len {
        cp, width := utf8_point(text, i)
        if cp == 34 { out = out + '\\"' }
        else if cp == 92 { out = out + '\\\\' }
        else if cp == 8 { out = out + '\\b' }
        else if cp == 9 { out = out + '\\t' }
        else if cp == 10 { out = out + '\\n' }
        else if cp == 12 { out = out + '\\f' }
        else if cp == 13 { out = out + '\\r' }
        else if cp < 32 { out = out + '\\u' + hex4(cp) }
        else if ensure_ascii && cp > 127 {
            if cp <= 65535 { out = out + '\\u' + hex4(cp) }
            else {
                n := cp - 65536
                out = out + '\\u' + hex4(0xd800 + n / 1024) + '\\u' + hex4(0xdc00 + n % 1024)
            }
        } else { out = out + text[i .. i + width] }
        i = i + width
    }
    return out + '"'
}

fn repeat_spaces(n int) string {
    mut out := ''
    for _ in 0 .. n { out = out + ' ' }
    return out
}

fn dict_key_text(key pyrt.Value) !string {
    match key {
        string { return key }
        i64, int { return pyrt.str(key) }
        bool { return if key { 'true' } else { 'false' } }
        f64 {
            text := pyrt.repr(key)
            return match text {
                'nan' { 'NaN' }
                'inf' { 'Infinity' }
                '-inf' { '-Infinity' }
                else { text }
            }
        }
        pyrt.NoneType { return 'null' }
        else { return pyrt.raise('TypeError', 'keys must be str, int, float, bool or None, not ${pyrt.type_name(key)}') }
    }
}

fn is_json_sequence(v pyrt.Value) bool {
    return match v {
        &pyrt.List, &pyrt.Tuple, pyrt.Sequence { true }
        else { false }
    }
}

fn encode_value(v pyrt.Value, opts DumpOptions, depth int, ancestors []i64) !string {
    if depth > 256 { return pyrt.raise('RecursionError', 'maximum recursion depth exceeded while encoding a JSON object') }
    match v {
        pyrt.NoneType { return 'null' }
        bool { return if v { 'true' } else { 'false' } }
        i64, int { return pyrt.str(v) }
        string { return quote_json(v, opts.ensure_ascii) }
        f64 {
            text := pyrt.repr(v)
            if text == 'nan' || text == 'inf' || text == '-inf' {
                if !opts.allow_nan { return pyrt.raise('ValueError', 'Out of range float values are not JSON compliant: ${text}') }
                return match text { 'nan' { 'NaN' } 'inf' { 'Infinity' } else { '-Infinity' } }
            }
            return text
        }
        else {}
    }
    // A copy outside the sum-type branch avoids ec510e2 multi-variant casts.
    whole := v
    if is_json_sequence(v) {
        id := pyrt.object_identity(whole)
        if id != 0 && id in ancestors { return pyrt.raise('ValueError', 'Circular reference detected') }
        mut path := ancestors.clone()
        if id != 0 { path << id }
        items := pyrt.iter(whole)!
        mut parts := []string{}
        for item in items { parts << encode_value(item, opts, depth + 1, path)! }
        if parts.len == 0 { return '[]' }
        mut indent_size := -1
        if size := opts.indent { indent_size = if size < 0 { 0 } else { size } }
        if indent_size < 0 {
            sep := if opts.separators.len == 2 { opts.separators[0] } else { ', ' }
            return '[' + parts.join(sep) + ']'
        }
        prefix := repeat_spaces(indent_size * (depth + 1))
        separator := if opts.separators.len == 2 { opts.separators[0] } else { ',' }
        return '[\n' + prefix + parts.join(separator + '\n' + prefix) + '\n' + repeat_spaces(indent_size * depth) + ']'
    }
    if v is &pyrt.Dict {
        id := pyrt.object_identity(whole)
        if id != 0 && id in ancestors { return pyrt.raise('ValueError', 'Circular reference detected') }
        mut path := ancestors.clone()
        if id != 0 { path << id }
        mut keys := v.keys.clone()
        if opts.sort_keys {
            // Selection sort by actual Python key comparisons, not repr.
            for i in 0 .. keys.len {
                mut minimum := i
                mut j := i + 1
                for j < keys.len {
                    if pyrt.lt(keys[j], keys[minimum])! { minimum = j }
                    j = j + 1
                }
                old := keys[i]
                keys[i] = keys[minimum]
                keys[minimum] = old
            }
        }
        mut parts := []string{}
        mut indent_size := -1
        if size := opts.indent { indent_size = if size < 0 { 0 } else { size } }
        separator_colon := if opts.separators.len == 2 { opts.separators[1] } else { ': ' }
        for key in keys {
            hash := pyrt.hash_key(key)!
            item := v.values[hash] or { return pyrt.raise('KeyError', pyrt.str(key)) }
            parts << quote_json(dict_key_text(key)!, opts.ensure_ascii) + separator_colon + encode_value(item, opts, depth + 1, path)!
        }
        if parts.len == 0 { return '{}' }
        if indent_size < 0 {
            sep := if opts.separators.len == 2 { opts.separators[0] } else { ', ' }
            return '{' + parts.join(sep) + '}'
        }
        prefix := repeat_spaces(indent_size * (depth + 1))
        sep := if opts.separators.len == 2 { opts.separators[0] } else { ',' }
        return '{\n' + prefix + parts.join(sep + '\n' + prefix) + '\n' + repeat_spaces(indent_size * depth) + '}'
    }
    if opts.default_str { return quote_json(pyrt.str(v), opts.ensure_ascii) }
    return pyrt.raise('TypeError', 'Object of type ${pyrt.type_name(v)} is not JSON serializable')
}

pub fn dumps(v pyrt.Value, opts DumpOptions) !string {
    if opts.separators.len != 0 && opts.separators.len != 2 {
        return pyrt.raise('ValueError', 'separators must contain exactly two strings')
    }
    return encode_value(v, opts, 0, []i64{})!
}

// These file-oriented APIs intentionally take a path, not an open V File.
// CPython dump(obj, fp) takes a file-like object; py2v must lower its handle.
pub fn dump_to(v pyrt.Value, path string, opts DumpOptions) ! {
    text := dumps(v, opts)!
    os.write_file(path, text) or { return pyrt.raise('OSError', err.msg()) }
}
