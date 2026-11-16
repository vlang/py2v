module pyrt

// Central CPython builtin-method bridge for values whose static type is not
// known to py2v. No V standard-library calls beyond the pinned reference.
// Mutable containers retain the same object identity after mutating calls.

fn arity(name string, typ string, args []Value, min_count int, max_count int) ! {
    if args.len >= min_count && args.len <= max_count { return }
    if min_count == max_count {
        if min_count == 0 { return raise('TypeError', '${typ}.${name}() takes no arguments (${args.len} given)') }
        return raise('TypeError', '${typ}.${name}() takes exactly ${min_count} arguments (${args.len} given)')
    }
    if args.len < min_count { return raise('TypeError', '${typ}.${name}() takes at least ${min_count} argument (${args.len} given)') }
    return raise('TypeError', '${typ}.${name}() takes at most ${max_count} arguments (${args.len} given)')
}

fn need_int(v Value, description string) !int {
    if is_integral(v) { return int(integral_value(v)) }
    return raise('TypeError', '${description} must be int, not ${type_name(v)}')
}

fn need_str(v Value) !string {
    if v is string { return v }
    return raise('TypeError', 'must be str, not ${type_name(v)}')
}

fn bound(index int, n int) int {
    mut i := index
    if i < 0 { i = i + n }
    if i < 0 { return 0 }
    return if i > n { n } else { i }
}

fn chars_find(hay []string, needle []string, start int, end int, reverse bool) int {
    if start > end || needle.len > end - start { return -1 }
    if reverse {
        mut i := end - needle.len
        for i >= start {
            mut found := true
            for j in 0 .. needle.len { if hay[i + j] != needle[j] { found = false; break } }
            if found { return i }
            i = i - 1
        }
        return -1
    }
    for i in start .. end - needle.len + 1 {
        mut found := true
        for j in 0 .. needle.len { if hay[i + j] != needle[j] { found = false; break } }
        if found { return i }
    }
    return -1
}

fn find_with_bounds(source string, part string, args []Value, reverse bool) !int {
    chars := utf8_parts(source)
    needle := utf8_parts(part)
    mut start := 0
    mut end := chars.len
    if args.len >= 2 {
        start = need_int(args[1], 'slice index')!
        if start < 0 { start = start + chars.len }
        if start < 0 { start = 0 }
    }
    if args.len >= 3 { end = bound(need_int(args[2], 'slice index')!, chars.len) }
    // Python's find('', start>L) fails even though bound would clamp to L.
    if start > chars.len { return -1 }
    return chars_find(chars, needle, start, end, reverse)
}

fn case_convert(source string, which string) string {
    mut out := ''
    mut start_word := true
    mut first := true
    for part in utf8_parts(source) {
        if which == 'upper' { out = out + codepoint_upper(part) }
        else if which == 'lower' { out = out + codepoint_lower(part) }
        else if which == 'title' {
            out = out + if start_word { codepoint_title(part) } else { codepoint_lower(part) }
            start_word = !(codepoint_isupper(part) || codepoint_islower(part) || codepoint_isalpha(part))
        } else if which == 'capitalize' {
            out = out + if first { codepoint_title(part) } else { codepoint_lower(part) }
        }
        first = false
    }
    return out
}

fn strip_side(source string, chars_arg Value, side string) !string {
    mut trim_chars := []string{}
    mut default_whitespace := true
    if chars_arg is string { trim_chars = utf8_parts(chars_arg); default_whitespace = false }
    else if chars_arg !is NoneType {
        method_name := if side == 'left' { 'lstrip' } else if side == 'right' { 'rstrip' } else { 'strip' }
        return raise('TypeError', '${method_name} arg must be None or str')
    }
    chars := utf8_parts(source)
    mut lo := 0
    mut hi := chars.len
    if side != 'right' {
        for lo < hi {
            if !(if default_whitespace { codepoint_isspace(chars[lo]) } else { chars[lo] in trim_chars }) { break }
            lo = lo + 1
        }
    }
    if side != 'left' {
        for hi > lo {
            if !(if default_whitespace { codepoint_isspace(chars[hi - 1]) } else { chars[hi - 1] in trim_chars }) { break }
            hi = hi - 1
        }
    }
    return chars[lo .. hi].join('')
}

fn split_text(source string, separator Value, maxsplit int, from_right bool) ![]Value {
    chars := utf8_parts(source)
    mut pieces := []Value{}
    if separator is NoneType {
        // Whitespace mode skips boundary runs. Python rsplit(None, 0)
        // has distinct trailing rather than leading whitespace semantics.
        mut left := 0
        mut right := chars.len
        if !from_right {
            for left < right && codepoint_isspace(chars[left]) { left = left + 1 }
            if maxsplit == 0 { if left < right { pieces << Value(chars[left .. right].join('')) }; return pieces }
            mut splits := 0
            for left < right {
                if maxsplit >= 0 && splits >= maxsplit { pieces << Value(chars[left .. right].join('')); return pieces }
                mut end := left
                for end < right && !codepoint_isspace(chars[end]) { end = end + 1 }
                pieces << Value(chars[left .. end].join(''))
                left = end
                for left < right && codepoint_isspace(chars[left]) { left = left + 1 }
                splits = splits + 1
            }
            return pieces
        }
        for right > left && codepoint_isspace(chars[right - 1]) { right = right - 1 }
        if maxsplit == 0 { if right > left { pieces << Value(chars[left .. right].join('')) }; return pieces }
        mut rev := []Value{}
        mut splits := 0
        for left < right {
            if maxsplit >= 0 && splits >= maxsplit { rev << Value(chars[left .. right].join('')); break }
            mut begin := right
            for begin > left && !codepoint_isspace(chars[begin - 1]) { begin = begin - 1 }
            rev << Value(chars[begin .. right].join(''))
            right = begin
            for right > left && codepoint_isspace(chars[right - 1]) { right = right - 1 }
            splits = splits + 1
        }
        mut i := rev.len
        for i > 0 { i = i - 1; pieces << rev[i] }
        return pieces
    }
    if separator !is string { return raise('TypeError', 'must be str or None, not ${type_name(separator)}') }
    delim := utf8_parts(separator)
    if delim.len == 0 { return raise('ValueError', 'empty separator') }
    if from_right {
        mut end := chars.len
        mut rev := []Value{}
        mut splits := 0
        for maxsplit < 0 || splits < maxsplit {
            at := chars_find(chars, delim, 0, end, true)
            if at < 0 { break }
            rev << Value(chars[at + delim.len .. end].join(''))
            end = at
            splits = splits + 1
        }
        rev << Value(chars[0 .. end].join(''))
        mut i := rev.len
        for i > 0 { i = i - 1; pieces << rev[i] }
    } else {
        mut at := 0
        mut splits := 0
        for maxsplit < 0 || splits < maxsplit {
            match_at := chars_find(chars, delim, at, chars.len, false)
            if match_at < 0 { break }
            pieces << Value(chars[at .. match_at].join(''))
            at = match_at + delim.len
            splits = splits + 1
        }
        pieces << Value(chars[at .. chars.len].join(''))
    }
    return pieces
}

fn starts_or_ends(source string, candidate Value, args []Value, ending bool) !bool {
    chars := utf8_parts(source)
    mut start := 0
    mut end := chars.len
    if args.len >= 2 {
        start = need_int(args[1], 'slice index')!
        if start < 0 { start = start + chars.len }
        if start < 0 { start = 0 }
    }
    if args.len >= 3 { end = bound(need_int(args[2], 'slice index')!, chars.len) }
    if start > chars.len || end < start { return false }
    mut candidates := []Value{}
    if candidate is &Tuple { candidates = candidate.items.clone() }
    else { candidates << candidate }
    for item in candidates {
        if item !is string { return raise('TypeError', 'tuple for startswith must only contain str, not ${type_name(item)}') }
        needle := utf8_parts(item)
        if needle.len > end - start { continue }
        at := if ending { end - needle.len } else { start }
        if chars[at .. at + needle.len] == needle { return true }
    }
    return false
}

fn text_replace(source string, old string, replacement string, limit int) string {
    chars := utf8_parts(source)
    needle := utf8_parts(old)
    mut result := ''
    mut pos := 0
    mut replacements := 0
    if needle.len == 0 {
        for i in 0 .. chars.len + 1 {
            if limit < 0 || replacements < limit {
                result = result + replacement
                replacements = replacements + 1
            }
            if i < chars.len { result = result + chars[i] }
        }
        return result
    }
    for limit < 0 || replacements < limit {
        at := chars_find(chars, needle, pos, chars.len, false)
        if at < 0 { break }
        result = result + chars[pos .. at].join('') + replacement
        pos = at + needle.len
        replacements = replacements + 1
    }
    return result + chars[pos .. chars.len].join('')
}

fn string_alignment(source string, width int, fill string, method string) string {
    padding := width - utf8_parts(source).len
    if padding <= 0 { return source }
    mut left := 0
    mut right := 0
    if method == 'ljust' { right = padding }
    if method == 'rjust' { left = padding }
    if method == 'center' {
        left = padding / 2
        if width % 2 != 0 && utf8_parts(source).len % 2 == 0 { left = left + 1 }
        right = padding - left
    }
    mut out := ''
    for _ in 0 .. left { out = out + fill }
    out = out + source
    for _ in 0 .. right { out = out + fill }
    return out
}

fn string_zfill(source string, width int) string {
    padding := width - utf8_parts(source).len
    if padding <= 0 { return source }
    mut front := ''
    mut rest := source
    if source.len > 0 && (source[0] == 43 || source[0] == 45) {
        front = source[0 .. 1]
        rest = source[1 .. source.len]
    }
    for _ in 0 .. padding { front = front + '0' }
    return front + rest
}

fn is_line_break(ch string) bool {
    cp := unicode_point(ch)
    return cp == 10 || cp == 13 || cp == 11 || cp == 12 || cp == 28 || cp == 29 || cp == 30 || cp == 133 || cp == 8232 || cp == 8233
}

fn text_splitlines(source string, keep bool) []Value {
    chars := utf8_parts(source)
    mut out := []Value{}
    mut pos := 0
    mut i := 0
    for i < chars.len {
        if !is_line_break(chars[i]) { i = i + 1; continue }
        mut after := i + 1
        if chars[i] == '\r' && after < chars.len && chars[after] == '\n' { after = after + 1 }
        out << Value(chars[pos .. if keep { after } else { i }].join(''))
        pos = after
        i = after
    }
    if pos < chars.len { out << Value(chars[pos .. chars.len].join('')) }
    return out
}

fn str_predicate(source string, mode string) bool {
    chars := utf8_parts(source)
    if chars.len == 0 { return false }
    mut cased := false
    for ch in chars {
        if mode == 'isdigit' && !codepoint_isdigit(ch) { return false }
        if mode == 'isalpha' && !codepoint_isalpha(ch) { return false }
        if mode == 'isalnum' && !codepoint_isalnum(ch) { return false }
        if mode == 'isspace' && !codepoint_isspace(ch) { return false }
        if mode == 'isupper' || mode == 'islower' {
            if codepoint_islower(ch) || codepoint_isupper(ch) || codepoint_istitle(ch) {
                cased = true
                if mode == 'isupper' && !codepoint_isupper(ch) { return false }
                if mode == 'islower' && !codepoint_islower(ch) { return false }
            }
        }
    }
    return if mode == 'isupper' || mode == 'islower' { cased } else { true }
}

fn text_format(source string, values []Value) !string {
    mut out := ''
    mut i := 0
    mut automatic := 0
    mut explicit := false
    mut using_automatic := false
    for i < source.len {
        if source[i] == 123 {
            if i + 1 < source.len && source[i + 1] == 123 { out = out + '{'; i = i + 2; continue }
            mut end := i + 1
            for end < source.len && source[end] != 125 { end = end + 1 }
            if end >= source.len { return raise('ValueError', "expected '}' before end of string") }
            field := source[i + 1 .. end]
            mut number := 0
            mut raw := field
            mut conversion := ''
            mut spec := ''
            for j in 0 .. field.len {
                if field[j] == 33 || field[j] == 58 {
                    raw = field[0 .. j]
                    if field[j] == 33 { conversion = field[j + 1 .. field.len] }
                    else { spec = field[j + 1 .. field.len] }
                    break
                }
            }
            if raw == '' {
                if explicit { return raise('ValueError', 'cannot switch from manual field specification to automatic field numbering') }
                using_automatic = true
                number = automatic
                automatic = automatic + 1
            } else {
                if using_automatic { return raise('ValueError', 'cannot switch from automatic field numbering to manual field specification') }
                explicit = true
                for k in 0 .. raw.len {
                    if raw[k] < 48 || raw[k] > 57 { return raise('KeyError', raw) }
                    number = number * 10 + int(raw[k] - 48)
                }
            }
            if number < 0 || number >= values.len { return raise('IndexError', 'Replacement index ${number} out of range for positional args tuple') }
            if spec != '' { return raise('NotImplementedError', 'str.format format specifications are not yet implemented') }
            v := values[number]
            if conversion == '' || conversion == '!s' || conversion == 's' { out = out + str(v) }
            else if conversion == '!r' || conversion == 'r' { out = out + repr(v) }
            else if conversion == '!a' || conversion == 'a' { out = out + repr(v) }
            else { return raise('ValueError', 'Unknown conversion specifier') }
            i = end + 1
        } else if source[i] == 125 {
            if i + 1 < source.len && source[i + 1] == 125 { out = out + '}'; i = i + 2 }
            else { return raise('ValueError', "Single '}' encountered in format string") }
        } else { out = out + source[i .. i + 1]; i = i + 1 }
    }
    return out
}

fn str_method(source string, name string, args []Value) !Value {
    if name == 'upper' || name == 'lower' || name == 'title' || name == 'capitalize' {
        arity(name, 'str', args, 0, 0)!
        return Value(case_convert(source, name))
    }
    if name == 'strip' || name == 'lstrip' || name == 'rstrip' {
        arity(name, 'str', args, 0, 1)!
        trim := if args.len == 0 { none_ } else { args[0] }
        return Value(strip_side(source, trim, if name == 'lstrip' { 'left' } else if name == 'rstrip' { 'right' } else { 'both' })!)
    }
    if name == 'split' || name == 'rsplit' {
        arity(name, 'str', args, 0, 2)!
        separator := if args.len >= 1 { args[0] } else { none_ }
        limit := if args.len >= 2 { need_int(args[1], 'maxsplit')! } else { -1 }
        return Value(new_list(split_text(source, separator, limit, name == 'rsplit')!))
    }
    if name == 'join' {
        arity(name, 'str', args, 1, 1)!
        joined_items := iter(args[0])!
        mut parts := []string{}
        for i, item in joined_items {
            if item !is string { return raise('TypeError', 'sequence item ${i}: expected str instance, ${type_name(item)} found') }
            parts << item
        }
        return Value(parts.join(source))
    }
    if name == 'replace' {
        arity(name, 'str', args, 2, 3)!
        old := need_str(args[0])!
        replacement := need_str(args[1])!
        limit := if args.len == 3 { need_int(args[2], 'count')! } else { -1 }
        return Value(text_replace(source, old, replacement, limit))
    }
    if name == 'startswith' || name == 'endswith' {
        arity(name, 'str', args, 1, 3)!
        return Value(starts_or_ends(source, args[0], args, name == 'endswith')!)
    }
    if name == 'find' || name == 'rfind' || name == 'index' {
        arity(name, 'str', args, 1, 3)!
        part := need_str(args[0])!
        at := find_with_bounds(source, part, args, name == 'rfind')!
        if name == 'index' && at < 0 { return raise('ValueError', 'substring not found') }
        return Value(i64(at))
    }
    if name == 'count' {
        arity(name, 'str', args, 1, 3)!
        part := need_str(args[0])!
        chars := utf8_parts(source)
        needle := utf8_parts(part)
        mut begin := 0
        mut end := chars.len
        if args.len >= 2 {
            raw_start := need_int(args[1], 'slice index')!
            if raw_start > chars.len { return Value(i64(0)) }
            begin = bound(raw_start, chars.len)
        }
        if args.len >= 3 { end = bound(need_int(args[2], 'slice index')!, chars.len) }
        if end < begin { return Value(i64(0)) }
        if needle.len == 0 { return Value(i64(end - begin + 1)) }
        mut count := 0
        for begin <= end - needle.len {
            i := chars_find(chars, needle, begin, end, false)
            if i < 0 { break }
            count = count + 1
            begin = i + needle.len
        }
        return Value(i64(count))
    }
    if name == 'isdigit' || name == 'isalpha' || name == 'isalnum' || name == 'isspace' || name == 'isupper' || name == 'islower' {
        arity(name, 'str', args, 0, 0)!
        return Value(str_predicate(source, name))
    }
    if name == 'zfill' {
        arity(name, 'str', args, 1, 1)!
        return Value(string_zfill(source, need_int(args[0], 'width')!))
    }
    if name == 'ljust' || name == 'rjust' || name == 'center' {
        arity(name, 'str', args, 1, 2)!
        width := need_int(args[0], 'width')!
        fill := if args.len == 2 { need_str(args[1])! } else { ' ' }
        if utf8_parts(fill).len != 1 { return raise('TypeError', 'The fill character must be exactly one character long') }
        return Value(string_alignment(source, width, fill, name))
    }
    if name == 'splitlines' {
        arity(name, 'str', args, 0, 1)!
        keep := args.len > 0 && truth(args[0])
        return Value(new_list(text_splitlines(source, keep)))
    }
    if name == 'partition' {
        arity(name, 'str', args, 1, 1)!
        separator := need_str(args[0])!
        if separator == '' { return raise('ValueError', 'empty separator') }
        chars := utf8_parts(source)
        at := chars_find(chars, utf8_parts(separator), 0, chars.len, false)
        if at < 0 { return Value(new_tuple([Value(source), Value(''), Value('')])) }
        delim_len := utf8_parts(separator).len
        return Value(new_tuple([Value(chars[0 .. at].join('')), Value(separator), Value(chars[at + delim_len .. chars.len].join(''))]))
    }
    if name == 'format' {
        return Value(text_format(source, args)!)
    }
    if name == 'encode' {
        arity(name, 'str', args, 0, 2)!
        encoding := if args.len >= 1 { need_str(args[0])! } else { 'utf-8' }
        mode := if args.len == 2 { need_str(args[1])! } else { 'strict' }
        if mode != 'strict' && mode != 'ignore' && mode != 'replace' { return raise('LookupError', 'unknown error handler name ${repr(Value(mode))}') }
        mut output := []u8{}
        if encoding == 'utf-8' || encoding == 'utf8' || encoding == 'UTF-8' {
            for i in 0 .. source.len { output << source[i] }
            return Value(output)
        }
        if encoding == 'utf-8-sig' {
            output << [u8(0xef), 0xbb, 0xbf]
            for i in 0 .. source.len { output << source[i] }
            return Value(output)
        }
        if encoding == 'ascii' || encoding == 'us-ascii' || encoding == 'latin-1' || encoding == 'latin1' || encoding == 'iso-8859-1' {
            top := if encoding == 'ascii' || encoding == 'us-ascii' { 127 } else { 255 }
            for part in utf8_parts(source) {
                cp := unicode_point(part)
                if cp <= top { output << u8(cp) }
                else if mode == 'ignore' { continue }
                else if mode == 'replace' { output << u8(63) }
                else { return raise('UnicodeEncodeError', "'${encoding}' codec can't encode character") }
            }
            return Value(output)
        }
        return raise('LookupError', 'unknown encoding: ${encoding}')
    }
    return raise('AttributeError', "'str' object has no attribute '${name}'")
}

fn list_search(items []Value, query Value, start int, end int) int {
    for i in start .. end { if eq(items[i], query) { return i } }
    return -1
}

fn list_method(list &List, name string, args []Value) !Value {
    if name == 'append' {
        arity(name, 'list', args, 1, 1)!
        unsafe { list.items << args[0] }
        return none_
    }
    if name == 'extend' {
        arity(name, 'list', args, 1, 1)!
        additions := iter(args[0])!
        unsafe { list.items << additions }
        return none_
    }
    if name == 'insert' {
        arity(name, 'list', args, 2, 2)!
        mut index := need_int(args[0], 'index')!
        if index < 0 { index = index + list.items.len }
        if index < 0 { index = 0 }
        if index > list.items.len { index = list.items.len }
        mut replacement := []Value{}
        replacement << list.items[0 .. index]
        replacement << args[1]
        replacement << list.items[index .. list.items.len]
        unsafe { list.items = replacement.clone() }
        return none_
    }
    if name == 'pop' {
        arity(name, 'list', args, 0, 1)!
        if list.items.len == 0 { return raise('IndexError', 'pop from empty list') }
        mut index := list.items.len - 1
        if args.len == 1 {
            index = need_int(args[0], 'index')!
            if index < 0 { index = index + list.items.len }
            if index < 0 || index >= list.items.len { return raise('IndexError', 'pop index out of range') }
        }
        found := list.items[index]
        delitem(Value(list), Value(i64(index)))!
        return found
    }
    if name == 'remove' {
        arity(name, 'list', args, 1, 1)!
        index := list_search(list.items, args[0], 0, list.items.len)
        if index < 0 { return raise('ValueError', 'list.remove(x): x not in list') }
        delitem(Value(list), Value(i64(index)))!
        return none_
    }
    if name == 'clear' {
        arity(name, 'list', args, 0, 0)!
        unsafe { list.items = []Value{} }
        return none_
    }
    if name == 'index' {
        arity(name, 'list', args, 1, 3)!
        start := if args.len >= 2 { bound(need_int(args[1], 'slice index')!, list.items.len) } else { 0 }
        end := if args.len == 3 { bound(need_int(args[2], 'slice index')!, list.items.len) } else { list.items.len }
        index := list_search(list.items, args[0], start, end)
        if index < 0 { return raise('ValueError', '${repr(args[0])} is not in list') }
        return Value(i64(index))
    }
    if name == 'count' {
        arity(name, 'list', args, 1, 1)!
        mut number := i64(0)
        for item in list.items { if eq(item, args[0]) { number = number + 1 } }
        return Value(number)
    }
    if name == 'copy' {
        arity(name, 'list', args, 0, 0)!
        return Value(new_list(list.items))
    }
    if name == 'reverse' {
        arity(name, 'list', args, 0, 0)!
        mut result := []Value{}
        mut i := list.items.len
        for i > 0 { i = i - 1; result << list.items[i] }
        unsafe { list.items = result.clone() }
        return none_
    }
    if name == 'sort' {
        arity(name, 'list', args, 0, 0)!
        mut sorted := list.items.clone()
        // Stable insertion sort without V generic comparison or external vlib.
        for i in 1 .. sorted.len {
            item := sorted[i]
            mut j := i
            for j > 0 {
                if !lt(item, sorted[j - 1])! { break }
                sorted[j] = sorted[j - 1]
                j = j - 1
            }
            sorted[j] = item
        }
        unsafe { list.items = sorted.clone() }
        return none_
    }
    return raise('AttributeError', "'list' object has no attribute '${name}'")
}

fn dict_get(d &Dict, key Value) !Value {
    token := hash_key(key)!
    return d.values[token] or { return key_error(key) }
}

fn dict_has(d &Dict, key Value) !bool {
    token := hash_key(key)!
    return token in d.values
}

fn dict_copy(d &Dict) !&Dict {
    cloned_dict := new_dict()
    for k in d.keys { setitem(Value(cloned_dict), k, dict_get(d, k)!)! }
    return cloned_dict
}

fn dict_update(d &Dict, source Value) ! {
    if source is &Dict {
        for k in source.keys { setitem(Value(d), k, dict_get(source, k)!)! }
        return
    }
    rows := iter(source)!
    for i, row in rows {
        pair := iter(row) or { return raise('TypeError', 'cannot convert dictionary update sequence element #${i} to a sequence') }
        if pair.len != 2 { return raise('ValueError', 'dictionary update sequence element #${i} has length ${pair.len}; 2 is required') }
        setitem(Value(d), pair[0], pair[1])!
    }
}

fn dict_method(d &Dict, name string, args []Value) !Value {
    if name == 'get' {
        arity(name, 'dict', args, 1, 2)!
        if dict_has(d, args[0])! { return dict_get(d, args[0])! }
        return if args.len == 2 { args[1] } else { none_ }
    }
    if name == 'keys' {
        arity(name, 'dict', args, 0, 0)!
        // Snapshot list, not Python's live dict_keys view.
        return Value(new_list(d.keys))
    }
    if name == 'values' {
        arity(name, 'dict', args, 0, 0)!
        mut out := []Value{}
        for key in d.keys { out << dict_get(d, key)! }
        return Value(new_list(out))
    }
    if name == 'items' {
        arity(name, 'dict', args, 0, 0)!
        mut out := []Value{}
        for key in d.keys { out << Value(new_tuple([key, dict_get(d, key)!])) }
        return Value(new_list(out))
    }
    if name == 'pop' {
        arity(name, 'dict', args, 1, 2)!
        if dict_has(d, args[0])! {
            found := dict_get(d, args[0])!
            delitem(Value(d), args[0])!
            return found
        }
        if args.len == 2 { return args[1] }
        return key_error(args[0])
    }
    if name == 'setdefault' {
        arity(name, 'dict', args, 1, 2)!
        if dict_has(d, args[0])! { return dict_get(d, args[0])! }
        value := if args.len == 2 { args[1] } else { none_ }
        setitem(Value(d), args[0], value)!
        return value
    }
    if name == 'update' {
        arity(name, 'dict', args, 0, 1)!
        if args.len == 1 { dict_update(d, args[0])! }
        return none_
    }
    if name == 'clear' {
        arity(name, 'dict', args, 0, 0)!
        unsafe { d.keys = []Value{}; d.values = map[string]Value{} }
        return none_
    }
    if name == 'copy' {
        arity(name, 'dict', args, 0, 0)!
        return Value(dict_copy(d)!)
    }
    return raise('AttributeError', "'dict' object has no attribute '${name}'")
}

fn set_copy(s &Set) !&Set {
    mut copied := new_set(s.items)!
    if s.frozen { unsafe { copied.frozen = true } }
    return copied
}

fn set_operation(s &Set, args []Value, action string) !Value {
    mut result := new_set(s.items)!
    for input in args {
        candidates := iter(input)!
        if action == 'union' {
            for item in candidates { result.add(item)! }
        } else if action == 'difference' {
            for item in candidates { result.discard(item)! }
        } else if action == 'intersection' {
            mut common := new_set([]Value{})!
            for item in result.items {
                for candidate in candidates {
                    if eq(item, candidate) { common.add(item)!; break }
                }
            }
            result = common
        }
    }
    if s.frozen { unsafe { result.frozen = true } }
    return Value(result)
}

fn set_method(s &Set, name string, args []Value) !Value {
    if s.frozen && name in ['add', 'discard', 'remove', 'pop', 'clear', 'update'] {
        return raise('AttributeError', "'frozenset' object has no attribute '${name}'")
    }
    if name == 'add' {
        arity(name, 'set', args, 1, 1)!
        s.add(args[0])!
        return none_
    }
    if name == 'discard' || name == 'remove' {
        arity(name, 'set', args, 1, 1)!
        if name == 'remove' && !contains(Value(s), args[0])! { return key_error(args[0]) }
        s.discard(args[0])!
        return none_
    }
    if name == 'pop' {
        arity(name, 'set', args, 0, 0)!
        if s.items.len == 0 { return raise('KeyError', 'pop from an empty set') }
        first := s.items[0]
        s.discard(first)!
        return first
    }
    if name == 'clear' {
        arity(name, 'set', args, 0, 0)!
        unsafe { s.items = []Value{}; s.index = map[string]bool{} }
        return none_
    }
    if name == 'copy' {
        arity(name, 'set', args, 0, 0)!
        if s.frozen { return Value(s) }
        return Value(set_copy(s)!)
    }
    if name == 'union' || name == 'intersection' || name == 'difference' {
        return set_operation(s, args, name)!
    }
    if name == 'update' {
        for input in args { for item in iter(input)! { s.add(item)! } }
        return none_
    }
    if name == 'isdisjoint' {
        arity(name, 'set', args, 1, 1)!
        for item in iter(args[0])! { if contains(Value(s), item)! { return Value(false) } }
        return Value(true)
    }
    if name == 'issubset' || name == 'issuperset' {
        arity(name, 'set', args, 1, 1)!
        other := new_set(iter(args[0])!)!
        if name == 'issubset' {
            for item in s.items { if !contains(Value(other), item)! { return Value(false) } }
        } else {
            for item in other.items { if !contains(Value(s), item)! { return Value(false) } }
        }
        return Value(true)
    }
    kind := if s.frozen { 'frozenset' } else { 'set' }
    return raise('AttributeError', "'${kind}' object has no attribute '${name}'")
}

fn tuple_method(t &Tuple, name string, args []Value) !Value {
    if name == 'index' {
        arity(name, 'tuple', args, 1, 3)!
        start := if args.len >= 2 { bound(need_int(args[1], 'slice index')!, t.items.len) } else { 0 }
        end := if args.len == 3 { bound(need_int(args[2], 'slice index')!, t.items.len) } else { t.items.len }
        at := list_search(t.items, args[0], start, end)
        if at < 0 { return raise('ValueError', 'tuple.index(x): x not in tuple') }
        return Value(i64(at))
    }
    if name == 'count' {
        arity(name, 'tuple', args, 1, 1)!
        mut count := i64(0)
        for value in t.items { if eq(value, args[0]) { count = count + 1 } }
        return Value(count)
    }
    return raise('AttributeError', "'tuple' object has no attribute '${name}'")
}

fn utf8_valid(bytes []u8) bool {
    mut i := 0
    for i < bytes.len {
        b := int(bytes[i])
        if b < 128 { i = i + 1; continue }
        mut sequence_len := 0
        mut cp := 0
        if b >= 194 && b <= 223 { sequence_len = 2; cp = b - 192 }
        else if b >= 224 && b <= 239 { sequence_len = 3; cp = b - 224 }
        else if b >= 240 && b <= 244 { sequence_len = 4; cp = b - 240 }
        else { return false }
        if i + sequence_len > bytes.len { return false }
        for j in 1 .. sequence_len {
            next := int(bytes[i + j])
            if next < 128 || next > 191 { return false }
            cp = cp * 64 + next - 128
        }
        if (sequence_len == 2 && cp < 128) || (sequence_len == 3 && cp < 2048) || (sequence_len == 4 && cp < 65536) { return false }
        if (cp >= 0xd800 && cp <= 0xdfff) || cp > 0x10ffff { return false }
        i = i + sequence_len
    }
    return true
}

fn bytes_to_text(bytes []u8, encoding string, errors string) !string {
    mut out := ''
    if encoding == 'ascii' || encoding == 'us-ascii' {
        for b in bytes {
            if b < 128 { out = out + byte_text(b) }
            else if errors == 'ignore' { continue }
            else if errors == 'replace' { out = out + '�' }
            else { return raise('UnicodeDecodeError', "'ascii' codec can't decode byte") }
        }
        return out
    }
    if encoding == 'latin-1' || encoding == 'latin1' || encoding == 'iso-8859-1' {
        for b in bytes { out = out + rune(int(b)).str() }
        return out
    }
    if encoding == 'utf-8' || encoding == 'utf8' || encoding == 'UTF-8' {
        if !utf8_valid(bytes) {
            // The limited API cannot identify every CPython error span.
            return raise('UnicodeDecodeError', "'utf-8' codec can't decode byte")
        }
        mut i := 0
        for i < bytes.len {
            b := int(bytes[i])
            if b < 128 { out = out + rune(b).str(); i = i + 1; continue }
            mut sequence_len := 2
            mut cp := b - 192
            if b >= 224 && b < 240 { sequence_len = 3; cp = b - 224 }
            if b >= 240 { sequence_len = 4; cp = b - 240 }
            for j in 1 .. sequence_len { cp = cp * 64 + int(bytes[i + j]) - 128 }
            out = out + rune(cp).str()
            i = i + sequence_len
        }
        return out
    }
    return raise('LookupError', 'unknown encoding: ${encoding}')
}

fn byte_text(b u8) string {
    return rune(int(b)).str()
}

fn bytes_method(bytes []u8, name string, args []Value) !Value {
    if name == 'decode' {
        arity(name, 'bytes', args, 0, 2)!
        encoding := if args.len >= 1 { need_str(args[0])! } else { 'utf-8' }
        errors := if args.len >= 2 { need_str(args[1])! } else { 'strict' }
        if errors != 'strict' && errors != 'ignore' && errors != 'replace' { return raise('LookupError', 'unknown error handler name ${repr(Value(errors))}') }
        return Value(bytes_to_text(bytes, encoding, errors)!)
    }
    if name == 'hex' {
        arity(name, 'bytes', args, 0, 2)!
        separator := if args.len >= 1 { need_str(args[0])! } else { '' }
        if separator != '' && utf8_parts(separator).len != 1 { return raise('ValueError', 'sep must be length 1.') }
        group := if args.len >= 2 { need_int(args[1], 'bytes_per_sep')! } else { 1 }
        if group == 0 { return raise('ValueError', 'bytes_per_sep must not be zero') }
        mut out := ''
        for i, b in bytes {
            if separator != '' && i > 0 {
                if group > 0 {
                    if (bytes.len - i) % group == 0 { out = out + separator }
                } else if i % -group == 0 { out = out + separator }
            }
            out = out + hex_fixed(int(b), 2)
        }
        return Value(out)
    }
    return raise('AttributeError', "'bytes' object has no attribute '${name}'")
}

pub fn call_method(v Value, name string, args []Value) !Value {
    // Dispatch each variant separately. Multi-variant match branches do not
    // smartcast on the pinned compiler; never test an interface against another.
    if v is string { return str_method(v, name, args)! }
    if v is &List { return list_method(v, name, args)! }
    if v is &Dict { return dict_method(v, name, args)! }
    if v is &Set { return set_method(v, name, args)! }
    if v is &Tuple { return tuple_method(v, name, args)! }
    if v is []u8 { return bytes_method(v, name, args)! }
    if v is Sequence {
        // A typed Sequence guarantees indexed operations, not list resizing.
        // It can expose snapshots but cannot implement append/extend safely.
        if name == 'copy' { return Value(new_list(iter(v)!)) }
        if name == 'count' {
            arity(name, 'list', args, 1, 1)!
            mut n := i64(0)
            for item in iter(v)! { if eq(item, args[0]) { n = n + 1 } }
            return Value(n)
        }
        return raise('NotImplementedError', 'typed Sequence does not support list method ${name}')
    }
    return raise('AttributeError', "'${type_name(v)}' object has no attribute '${name}'")
}
