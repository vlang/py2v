module re

import pyrt

fn test_regex_compile_search_and_flags() {
    p := compile('ab+c', 0) or { panic(err.msg()) }
    // python: __import__('re').compile('ab+c').pattern == 'ab+c'
    assert p.pattern == 'ab+c'
    // python: __import__('re').search('ab+c', 'xxabbczz').group(0) == 'abbc'
    m := p.search('xxabbczz') or { panic('missing match') }
    assert pyrt.str(m.group(0) or { panic(err.msg()) }) == 'abbc'
    // python: __import__('re').search('ab+c', 'xxabbczz').span() == (2,6)
    s := m.span(0) or { panic(err.msg()) }
    assert s.start == 2 && s.end == 6
    // python: __import__('re').match('ab+c','xxabbczz') is None
    assert p.match_('xxabbczz') == none
    // python: __import__('re').fullmatch('ab+c','abbc') is not None
    assert p.fullmatch('abbc') != none
    // python: __import__('re').search('ABC', 'xabc', __import__('re').I).group(0) == 'abc'
    ignore_case := compile('ABC', ignorecase) or { panic(err.msg()) }
    assert pyrt.str((ignore_case.search('xabc') or { panic('missing') }).group(0) or { panic(err.msg()) }) == 'abc'
    // python: __import__('re').search('^b','a\nb', __import__('re').M).start() == 2
    multiline_pattern := compile('^b', multiline) or { panic(err.msg()) }
    assert ((multiline_pattern.search('a\nb') or { panic('missing') }).start(0) or { panic(err.msg()) }) == 2
    // python: __import__('re').search('a.b','a\nb', __import__('re').S).group(0) == 'a\nb'
    dotall_pattern := compile('a.b', dotall) or { panic(err.msg()) }
    assert pyrt.str((dotall_pattern.search('a\nb') or { panic('missing') }).group(0) or { panic(err.msg()) }) == 'a\nb'
    // python: __import__('re').search('a  b', 'ab', __import__('re').X).group(0) == 'ab'
    verbose_pattern := compile('a  b', verbose) or { panic(err.msg()) }
    assert pyrt.str((verbose_pattern.search('ab') or { panic('missing') }).group(0) or { panic(err.msg()) }) == 'ab'
    // python: __import__('re').search(r'\d+', 'a123', 0).group(0) == '123'
    from_module := search('\\d+', 'a123', 0) or { panic(err.msg()) }
    assert from_module.has
    assert pyrt.str(from_module.value.group(0) or { panic(err.msg()) }) == '123'
    // python: __import__('re').match(r'\d+', '123x').group(0) == '123'
    matched := match_('\\d+', '123x', 0) or { panic(err.msg()) }
    assert matched.has
    // python: __import__('re').fullmatch(r'\d+', '123') is not None
    fully := fullmatch('\\d+', '123', 0) or { panic(err.msg()) }
    assert fully.has
}

fn test_regex_captures_and_groups() {
    p := compile('(?P<word>[a-z]+)-(\\d+)(?:x)?', 0) or { panic(err.msg()) }
    m := p.search('z abc-42x !') or { panic('missing') }
    // python: __import__('re').compile(r'(?P<word>[a-z]+)-(\d+)(?:x)?').groups == 2
    assert p.group_count == 2
    // python: __import__('re').search(r'(?P<word>[a-z]+)-(\d+)(?:x)?','z abc-42x !').group('word') == 'abc'
    assert pyrt.str(m.group_name('word') or { panic(err.msg()) }) == 'abc'
    // python: __import__('re').search(r'(?P<word>[a-z]+)-(\d+)(?:x)?','z abc-42x !').group(2) == '42'
    assert pyrt.str(m.group(2) or { panic(err.msg()) }) == '42'
    // python: __import__('re').search(r'(?P<word>[a-z]+)-(\d+)(?:x)?','z abc-42x !').start(1) == 2
    assert (m.start(1) or { panic(err.msg()) }) == 2
    // python: __import__('re').search(r'(?P<word>[a-z]+)-(\d+)(?:x)?','z abc-42x !').end(2) == 8
    assert (m.end(2) or { panic(err.msg()) }) == 8
    // python: __import__('re').search(r'(?P<word>[a-z]+)-(\d+)(?:x)?','z abc-42x !').groupdict() == {'word':'abc'}
    dict := m.groupdict()
    assert pyrt.str(dict['word']) == 'abc'
    // python: __import__('re').search(r'(x)?(a)', 'a').groups() == (None,'a')
    optional := (compile('(x)?(a)', 0) or { panic(err.msg()) }).search('a') or { panic('missing') }
    groups := optional.groups()
    assert groups.len == 2 && groups[0] is pyrt.NoneType && pyrt.str(groups[1]) == 'a'
    // python: __import__('re').search(r'(x)?(a)', 'a').span(1) == (-1,-1)
    missing := optional.span(1) or { panic(err.msg()) }
    assert missing.start == -1 && missing.end == -1
    // python: __import__('re').search('é','aé').span() == (1,2)
    unicode := (compile('é', 0) or { panic(err.msg()) }).search('aé') or { panic('missing') }
    loc := unicode.span(0) or { panic(err.msg()) }
    assert loc.start == 1 && loc.end == 2
}

fn test_regex_findall_finditer_split() {
    p := compile('\\d+', 0) or { panic(err.msg()) }
    // python: __import__('re').findall(r'\d+','a12 b34') == ['12','34']
    found := p.findall('a12 b34')
    assert found.len == 2 && pyrt.str(found[0]) == '12' && pyrt.str(found[1]) == '34'
    // python: [m.group() for m in __import__('re').finditer(r'\d+','a12 b34')] == ['12','34']
    matches := p.finditer('a12 b34')
    assert matches.len == 2 && pyrt.str(matches[0].group(0) or { panic(err.msg()) }) == '12'
    // python: __import__('re').findall(r'(\w+):(\d+)','a:2 b:3') == [('a','2'),('b','3')]
    pairs := findall('(\\w+):(\\d+)', 'a:2 b:3', 0) or { panic(err.msg()) }
    assert pairs.len == 2 && pyrt.repr(pairs[0]) == "('a', '2')"
    // python: __import__('re').split(r'\s+','a b  c') == ['a','b','c']
    pieces := split('\\s+', 'a b  c', 0, 0) or { panic(err.msg()) }
    assert pyrt.str(pyrt.Value(pyrt.new_list(pieces))) == "['a', 'b', 'c']"
    // python: __import__('re').split(r'(,)', 'a,b,c', 1) == ['a', ',', 'b,c']
    split_group := split('(,)', 'a,b,c', 1, 0) or { panic(err.msg()) }
    assert pyrt.str(pyrt.Value(pyrt.new_list(split_group))) == "['a', ',', 'b,c']"
    // python: [m.start() for m in __import__('re').finditer('b','abcbb')] == [1,3,4]
    found_positions := finditer('b', 'abcbb', 0) or { panic(err.msg()) }
    assert (found_positions[0].start(0) or { -1 }) == 1 && (found_positions[1].start(0) or { -1 }) == 3
}

fn replacement_upper(m Match) string {
    item := m.group(0) or { pyrt.Value('') }
    return '[' + pyrt.str(item) + ']'
}

fn test_regex_sub_and_escape() {
    p := compile('(a)(b)', 0) or { panic(err.msg()) }
    // python: __import__('re').sub(r'(a)(b)',r'\2\1','ab ab') == 'ba ba'
    assert (p.sub('\\2\\1', 'ab ab', 0) or { panic(err.msg()) }) == 'ba ba'
    // python: __import__('re').sub(r'(?P<x>a)b',r'\g<x>!','ab') == 'a!'
    named := compile('(?P<x>a)b', 0) or { panic(err.msg()) }
    assert (named.sub('\\g<x>!', 'ab', 0) or { panic(err.msg()) }) == 'a!'
    // python: __import__('re').subn('a','X','aaa',2) == ('XXa',2)
    subresult := subn('a', 'X', 'aaa', 2, 0) or { panic(err.msg()) }
    assert subresult.text == 'XXa' && subresult.count == 2
    // python: __import__('re').sub(r'\d+',lambda m:'['+m.group(0)+']','a1 b22') == 'a[1] b[22]'
    numeric := compile('\\d+', 0) or { panic(err.msg()) }
    assert (numeric.sub_callback(replacement_upper, 'a1 b22', 0) or { panic(err.msg()) }) == 'a[1] b[22]'
    // python: __import__('re').sub('x','y','x x',1) == 'y x'
    assert (sub('x','y','x x',1,0) or { panic(err.msg()) }) == 'y x'
    // python: __import__('re').escape('a.b-c #') == r'a\.b\-c\ \#'
    assert escape('a.b-c #') == 'a\\.b\\-c\\ \\#'
}

fn test_regex_errors() {
    // python: error_text(lambda: __import__('re').compile('(')).split('|')[0] in ('error','PatternError')
    _ = compile('(', 0) or { assert pyrt.caught(err, 're.error') != none; Pattern{} }
    // python: error_text(lambda: __import__('re').compile('x', __import__('re').LOCALE)).startswith('ValueError|')
    _ = compile('x', locale) or { assert pyrt.caught(err, 'NotImplementedError') != none; Pattern{} }
    // python: error_text(lambda: __import__('re').search('(x)', 'x').group(9)) == 'IndexError|no such group'
    matched := (compile('(x)', 0) or { panic(err.msg()) }).search('x') or { panic('missing') }
    _ = matched.group(9) or { assert err.msg() == 'no such group'; pyrt.none_ }
}

// Separates malformed Python syntax from unsupported *valid* capturing
// constructs; both can otherwise fail to produce a usable capture program.
fn malformed_regex_message(pattern string) string {
    _ = compile(pattern, 0) or {
        if e := pyrt.caught(err, 're.error') { return e.msg() }
        return 'WRONG_CLASS:' + err.msg()
    }
    return 'NO_ERROR'
}

fn test_regex_structural_pattern_errors() {
    // python: error_text(lambda: __import__('re').compile('(')).endswith('|missing ), unterminated subpattern at position 0')
    assert malformed_regex_message('(') == 'missing ), unterminated subpattern at position 0'
    // python: error_text(lambda: __import__('re').compile(')')).endswith('|unbalanced parenthesis at position 0')
    assert malformed_regex_message(')') == 'unbalanced parenthesis at position 0'
    // python: error_text(lambda: __import__('re').compile('[')).endswith('|unterminated character set at position 0')
    assert malformed_regex_message('[') == 'unterminated character set at position 0'
    // python: error_text(lambda: __import__('re').compile('\\')).endswith('|bad escape (end of pattern) at position 0')
    assert malformed_regex_message('\\') == 'bad escape (end of pattern) at position 0'
    // python: __import__('re').search(r'\(', '(').group(0) == '('
    literal := (compile('\\(', 0) or { panic(err.msg()) }).search('(') or { panic('literal parenthesis unmatched') }
    assert pyrt.str(literal.group(0) or { panic(err.msg()) }) == '('
    // python: __import__('re').search(r'[(]', '(').group(0) == '('
    class_match := (compile('[(]', 0) or { panic(err.msg()) }).search('(') or { panic('class parenthesis unmatched') }
    assert pyrt.str(class_match.group(0) or { panic(err.msg()) }) == '('
    // python: __import__('re').search(r'(x)', 'x').groups() == ('x',)
    captured := (compile('(x)', 0) or { panic(err.msg()) }).search('x') or { panic('no match for simple captured literal') }
    assert pyrt.str(captured.group(1) or { panic(err.msg()) }) == 'x'
}

fn test_verbose_syntax_and_escapes() {
    // python: __import__('re').search('a  b', 'ab', __import__('re').X).group() == 'ab'
    a := compile('a  b', verbose) or { panic(err.msg()) }
    assert pyrt.str((a.search('ab') or { panic('no match') }).group(0) or { panic(err.msg()) }) == 'ab'
    // python: __import__('re').search('a # comment\nb', 'ab', __import__('re').X).group() == 'ab'
    b := compile('a # comment\nb', verbose) or { panic(err.msg()) }
    assert pyrt.str((b.search('ab') or { panic('no match') }).group(0) or { panic(err.msg()) }) == 'ab'
    // python: __import__('re').search(r'a\ b', 'a b', __import__('re').X).group() == 'a b'
    c := compile('a\\ b', verbose) or { panic(err.msg()) }
    assert pyrt.str((c.search('a b') or { panic('no match') }).group(0) or { panic(err.msg()) }) == 'a b'
    // python: __import__('re').search(r'a\#b', 'a#b', __import__('re').X).group() == 'a#b'
    d := compile('a\\#b', verbose) or { panic(err.msg()) }
    assert pyrt.str((d.search('a#b') or { panic('no match') }).group(0) or { panic(err.msg()) }) == 'a#b'
    // python: __import__('re').search('[ #]+', '# #', __import__('re').X).group() == '# #'
    e := compile('[ #]+', verbose) or { panic(err.msg()) }
    assert pyrt.str((e.search('# #') or { panic('no match') }).group(0) or { panic(err.msg()) }) == '# #'
    // python: __import__('re').search(r'[\] #]+', '] #', __import__('re').X).group() == '] #'
    f := compile('[\\] #]+', verbose) or { panic(err.msg()) }
    assert pyrt.str((f.search('] #') or { panic('no match') }).group(0) or { panic(err.msg()) }) == '] #'
    // python: __import__('re').search('[]# ]+', ']# ', __import__('re').X).group() == ']# '
    g := compile('[]# ]+', verbose) or { panic(err.msg()) }
    assert pyrt.str((g.search(']# ') or { panic('no match') }).group(0) or { panic(err.msg()) }) == ']# '
}

// Round 8: leading literal ']' in a VERBOSE class and its escaped spelling.
fn test_verbose_leading_close_bracket_classes() {
    // python: __import__('re').compile(r'[\] #]+', __import__('re').VERBOSE).fullmatch('] #') is not None
    escaped := compile('[\\] #]+', verbose) or { panic(err.msg()) }
    assert escaped.fullmatch('] #') != none
    // python: __import__('re').compile(r'[]# ]+', __import__('re').VERBOSE).fullmatch('] #') is not None
    literal := compile('[]# ]+', verbose) or { panic(err.msg()) }
    assert literal.fullmatch('] #') != none
    // python: __import__('re').compile(r'[^]]+', __import__('re').VERBOSE).fullmatch('abc') is not None
    negated := compile('[^]]+', verbose) or { panic(err.msg()) }
    assert negated.fullmatch('abc') != none
    // python: __import__('re').compile(r'[^]]+', __import__('re').VERBOSE).fullmatch(']') is None
    assert negated.fullmatch(']') == none
    // python: __import__('re').compile(r'[\] #]+', __import__('re').VERBOSE).fullmatch('x') is None
    assert escaped.fullmatch('x') == none
    // python: __import__('re').compile(r'[]# ]+', __import__('re').VERBOSE).fullmatch('# ]') is not None
    assert literal.fullmatch('# ]') != none
}
