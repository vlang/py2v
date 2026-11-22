module pyrt

// Python's string % operator for logging. Typed integers include BOTH int and
// i64 through the core numeric helpers. Binary64 formatting below rounds the
// exact value, not its shortest repr (2.675 at two places must become 2.67).
struct PercentDecimal {
    digits string
    scale int
}

fn percent_repeat(text string, count int) string {
    mut out := ''
    for _ in 0 .. count { out = out + text }
    return out
}

fn percent_exact_decimal(value f64) PercentDecimal {
    if value == 0.0 { return PercentDecimal{digits: '0'} }
    mut normalized := if value < 0.0 { -value } else { value }
    mut exponent := 0
    for normalized >= 2.0 { normalized = normalized * 0.5; exponent = exponent + 1 }
    for normalized < 1.0 { normalized = normalized * 2.0; exponent = exponent - 1 }
    mut mantissa := i64(normalized * 4503599627370496.0)
    mut unit := exponent - 52
    if exponent < -1022 {
        for _ in 0 .. -1022 - exponent { mantissa = mantissa / 2 }
        unit = -1074
    }
    mut limbs := big_magnitude(mantissa)
    mut scale := 0
    if unit >= 0 { limbs = big_times_power_two(limbs, unit) }
    else {
        scale = -unit
        for _ in 0 .. scale { limbs = big_multiply_small(limbs, 5) }
    }
    mut digits := limbs[limbs.len - 1].str()
    mut i := limbs.len - 2
    for i >= 0 {
        part := limbs[i].str()
        digits = digits + percent_repeat('0', 9 - part.len) + part
        i = i - 1
    }
    return PercentDecimal{digits: digits, scale: scale}
}

fn percent_round(digits string, remove int) string {
    if remove <= 0 { return digits + percent_repeat('0', -remove) }
    at := digits.len - remove
    if at < 0 { return '0' }
    mut kept := if at == 0 { '0' } else { digits[0 .. at] }
    first := digits[at]
    mut remaining := false
    for i in at + 1 .. digits.len { if digits[i] != 48 { remaining = true; break } }
    odd := (kept[kept.len - 1] - 48) % 2 == 1
    if first > 53 || (first == 53 && (remaining || odd)) {
        mut i := kept.len - 1
        for i >= 0 && kept[i] == 57 { i = i - 1 }
        if i < 0 { kept = '1' + percent_repeat('0', kept.len) }
        else { kept = kept[0 .. i] + (int(kept[i] - 48) + 1).str() + percent_repeat('0', kept.len - i - 1) }
    }
    return kept
}

fn percent_fixed(digits string, places int, alternate bool) string {
    mut raw := digits
    if raw.len <= places { raw = percent_repeat('0', places + 1 - raw.len) + raw }
    if places == 0 { return raw + if alternate { '.' } else { '' } }
    at := raw.len - places
    return raw[0 .. at] + '.' + raw[at .. raw.len]
}

fn percent_trim_zeros(text string) string {
    if !text.contains('.') { return text }
    mut end := text.len
    for end > 0 && text[end - 1] == 48 { end = end - 1 }
    if end > 0 && text[end - 1] == 46 { end = end - 1 }
    return text[0 .. end]
}

fn percent_float(value f64, spec string, precision int, alternate bool) string {
    uppercase := spec in ['E', 'F', 'G']
    if float_is_nan(value) { return if uppercase { 'NAN' } else { 'nan' } }
    if float_is_inf(value) { return if uppercase { 'INF' } else { 'inf' } }
    p := if precision < 0 { 6 } else { precision }
    exact := percent_exact_decimal(value)
    if spec == 'f' || spec == 'F' {
        return percent_fixed(percent_round(exact.digits, exact.scale - p), p, alternate)
    }
    general := spec == 'g' || spec == 'G'
    significant := if general { if p == 0 { 1 } else { p } } else { p + 1 }
    mut exponent := if value == 0.0 { 0 } else { exact.digits.len - exact.scale - 1 }
    mut digits := percent_round(exact.digits, exact.digits.len - significant)
    if digits.len > significant { exponent = exponent + 1; digits = digits[0 .. significant] }
    scientific := !general || exponent < -4 || exponent >= significant
    mut result := ''
    if scientific {
        result = digits[0 .. 1]
        if digits.len > 1 || alternate { result = result + '.' + digits[1 .. digits.len] }
        if general && !alternate { result = percent_trim_zeros(result) }
        marker := if uppercase { 'E' } else { 'e' }
        sign := if exponent < 0 { '-' } else { '+' }
        magnitude := if exponent < 0 { -exponent } else { exponent }
        number := magnitude.str()
        return result + marker + sign + percent_repeat('0', 2 - number.len) + number
    }
    point := exponent + 1
    if point <= 0 { result = '0.' + percent_repeat('0', -point) + digits }
    else if point >= digits.len { result = digits + percent_repeat('0', point - digits.len) + if alternate { '.' } else { '' } }
    else { result = digits[0 .. point] + '.' + digits[point .. digits.len] }
    return if alternate { result } else { percent_trim_zeros(result) }
}

fn percent_integer(value i64, base int, uppercase bool) string {
    alphabet := if uppercase { '0123456789ABCDEF' } else { '0123456789abcdef' }
    mut n := value
    mut result := ''
    for n != 0 {
        raw := n % i64(base)
        digit := int(if raw < 0 { -raw } else { raw })
        result = alphabet[digit .. digit + 1] + result
        n = n / i64(base)
    }
    return if result == '' { '0' } else { result }
}

fn percent_ascii(value Value) string {
    mut out := ''
    for part in utf8_parts(repr(value)) {
        cp := unicode_point(part)
        if cp < 128 { out = out + part }
        else if cp < 256 { out = out + '\\x' + hex_fixed(cp, 2) }
        else if cp < 65536 { out = out + '\\u' + hex_fixed(cp, 4) }
        else { out = out + '\\U' + hex_fixed(cp, 8) }
    }
    return out
}

fn percent_pad(body string, sign string, prefix string, width int, left bool, zero bool, numeric bool) string {
    amount := width - body.runes().len - sign.len - prefix.len
    if amount <= 0 { return sign + prefix + body }
    if left { return sign + prefix + body + percent_repeat(' ', amount) }
    if zero && numeric { return sign + prefix + percent_repeat('0', amount) + body }
    return percent_repeat(' ', amount) + sign + prefix + body
}

fn percent_value(value Value, spec string, width int, precision int, left bool, zero bool, plus bool, blank bool, alternate bool, index int) !string {
    mut body := ''
    mut sign := ''
    mut prefix := ''
    mut numeric := false
    if spec in ['s', 'r', 'a'] {
        body = if spec == 's' { str(value) } else if spec == 'r' { repr(value) } else { percent_ascii(value) }
        if precision >= 0 {
            parts := utf8_parts(body)
            if precision < parts.len { body = parts[0 .. precision].join('') }
        }
    } else if spec == 'c' {
        if value is string {
            if value.runes().len != 1 { return raise('TypeError', '%c requires int or char') }
            body = value
        } else if is_integral(value) {
            n := integral_value(value)
            if n < 0 || n > 0x10ffff { return raise('OverflowError', '%c arg not in range(0x110000)') }
            body = rune(n).str()
        } else { return raise('TypeError', '%c requires int or char') }
    } else if spec in ['d', 'i', 'u', 'o', 'x', 'X'] {
        numeric = true
        mut integer := i64(0)
        if is_integral(value) { integer = integral_value(value) }
        else if value is f64 {
            if spec in ['o', 'x', 'X'] { return raise('TypeError', '%${spec} format: an integer is required, not float') }
            if float_is_nan(value) { return raise('ValueError', 'cannot convert float NaN to integer') }
            if float_is_inf(value) { return raise('OverflowError', 'cannot convert float infinity to integer') }
            if value < int_float_lower || value >= int_float_upper { integer_overflow('float to integer conversion', @FILE_LINE) }
            integer = i64(value)
        } else {
            needed := if spec in ['o', 'x', 'X'] { 'an integer' } else { 'a real number' }
            return raise('TypeError', '%${spec} format: ${needed} is required, not ${type_name(value)}')
        }
        base := if spec == 'o' { 8 } else if spec == 'x' || spec == 'X' { 16 } else { 10 }
        body = percent_integer(integer, base, spec == 'X')
        if precision > body.len { body = percent_repeat('0', precision - body.len) + body }
        if integer < 0 { sign = '-' } else if plus { sign = '+' } else if blank { sign = ' ' }
        if alternate {
            if spec == 'o' { prefix = '0o' }
            if spec == 'x' { prefix = '0x' }
            if spec == 'X' { prefix = '0X' }
        }
    } else if spec in ['e', 'E', 'f', 'F', 'g', 'G'] {
        numeric = true
        if !is_numeric(value) { return raise('TypeError', 'must be real number, not ${type_name(value)}') }
        number := numeric_float(value)
        body = percent_float(number, spec, precision, alternate)
        if float_negative(number) { sign = '-' } else if plus { sign = '+' } else if blank { sign = ' ' }
    } else {
        cp := unicode_point(spec)
        mut hexadecimal := percent_integer(i64(cp), 16, false)
        if hexadecimal.len < 2 { hexadecimal = '0' + hexadecimal }
        return raise('ValueError', "unsupported format character '${spec}' (0x${hexadecimal}) at index ${index}")
    }
    return percent_pad(body, sign, prefix, width, left, zero, numeric)
}

fn percent_star(value Value) !int {
    if !is_integral(value) { return raise('TypeError', '* wants int') }
    n := integral_value(value)
    if n < -1000000 || n > 1000000 { return raise('OverflowError', 'percent format field exceeds runtime limit') }
    return int(n)
}

// The operand is the Python RHS: a tuple for positional arguments, a dict for
// mapping interpolation, or a single scalar. No formatting is evaluated by
// logging until an enabled handler actually needs the rendered message.
pub fn percent_format(template string, operand Value) !string {
    mut format_args := [operand]
    mut mapping := false
    if operand is &Tuple { format_args = operand.items.clone() }
    if operand is &Dict { mapping = true }
    parts := utf8_parts(template)
    mut at := 0
    mut consumed := 0
    mut out := ''
    for at < parts.len {
        if parts[at] != '%' { out = out + parts[at]; at = at + 1; continue }
        at = at + 1
        if at >= parts.len { return raise('ValueError', 'incomplete format') }
        if parts[at] == '%' { out = out + '%'; at = at + 1; continue }
        mut keyed := false
        mut mapped := none_
        if parts[at] == '(' {
            if !mapping { return raise('TypeError', 'format requires a mapping') }
            at = at + 1
            mut depth := 1
            mut key := ''
            for at < parts.len {
                if parts[at] == '(' { depth = depth + 1 }
                if parts[at] == ')' { depth = depth - 1; if depth == 0 { break } }
                key = key + parts[at]
                at = at + 1
            }
            if at >= parts.len { return raise('ValueError', 'incomplete format key') }
            mapped = getitem(operand, Value(key))!
            keyed = true
            consumed = format_args.len
            at = at + 1
        }
        mut left := false
        mut zero := false
        mut plus_flag := false
        mut blank := false
        mut alternate := false
        for at < parts.len && parts[at] in ['-', '0', '+', ' ', '#'] {
            flag := parts[at]
            if flag == '-' { left = true }
            if flag == '0' { zero = true }
            if flag == '+' { plus_flag = true }
            if flag == ' ' { blank = true }
            if flag == '#' { alternate = true }
            at = at + 1
        }
        mut width := 0
        if at < parts.len && parts[at] == '*' {
            if keyed {
                _ = percent_star(mapped)!
                return raise('TypeError', 'not enough arguments for format string')
            }
            if consumed >= format_args.len { return raise('TypeError', 'not enough arguments for format string') }
            width = percent_star(format_args[consumed])!
            consumed = consumed + 1
            at = at + 1
            if width < 0 { left = true; width = -width }
        } else {
            for at < parts.len && parts[at] >= '0' && parts[at] <= '9' {
                width = width * 10 + int(parts[at][0] - 48)
                if width > 1000000 { return raise('OverflowError', 'percent format field exceeds runtime limit') }
                at = at + 1
            }
        }
        mut precision := -1
        if at < parts.len && parts[at] == '.' {
            at = at + 1
            precision = 0
            if at < parts.len && parts[at] == '*' {
                if keyed { _ = percent_star(mapped)!; return raise('TypeError', 'not enough arguments for format string') }
                if consumed >= format_args.len { return raise('TypeError', 'not enough arguments for format string') }
                precision = percent_star(format_args[consumed])!
                if precision < 0 { precision = 0 }
                consumed = consumed + 1
                at = at + 1
            } else {
                for at < parts.len && parts[at] >= '0' && parts[at] <= '9' {
                    precision = precision * 10 + int(parts[at][0] - 48)
                    if precision > 10000 { return raise('OverflowError', 'percent format precision exceeds runtime limit') }
                    at = at + 1
                }
            }
        }
        if precision > 10000 { return raise('OverflowError', 'percent format precision exceeds runtime limit') }
        if at < parts.len && parts[at] in ['h', 'l', 'L'] { at = at + 1 }
        if at >= parts.len { return raise('ValueError', 'incomplete format') }
        mut value := mapped
        if !keyed {
            if consumed >= format_args.len { return raise('TypeError', 'not enough arguments for format string') }
            value = format_args[consumed]
            consumed = consumed + 1
        }
        out = out + percent_value(value, parts[at], width, precision, left, zero, plus_flag, blank, alternate, at)!
        at = at + 1
    }
    if !mapping && consumed < format_args.len { return raise('TypeError', 'not all arguments converted during string formatting') }
    return out
}
