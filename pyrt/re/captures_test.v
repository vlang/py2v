module re

import pyrt

fn capture_tuple(pattern string, text string) string {
    p := compile(pattern, 0) or { panic(err.msg()) }
    m := p.search(text) or { panic('missing capture match') }
    return pyrt.repr(pyrt.Value(pyrt.new_tuple(m.groups())))
}

fn test_optional_capture_values() {
    // python: __import__('re').search('(x)?(a)', 'a').groups() == (None, 'a')
    assert capture_tuple('(x)?(a)', 'a') == "(None, 'a')"
    // python: __import__('re').search('(a)|(b)', 'b').groups() == (None, 'b')
    assert capture_tuple('(a)|(b)', 'b') == "(None, 'b')"
    // python: __import__('re').search('(a)|(b)', 'a').groups() == ('a', None)
    assert capture_tuple('(a)|(b)', 'a') == "('a', None)"
    // python: __import__('re').search('(a)?b', 'b').groups() == (None,)
    assert capture_tuple('(a)?b', 'b') == '(None,)'
    // python: __import__('re').search('(?:(a)|b)+', 'abb').groups() == ('a',)
    assert capture_tuple('(?:(a)|b)+', 'abb') == "('a',)"
    // python: __import__('re').search('(?:(a)|b)+', 'bbb').groups() == (None,)
    assert capture_tuple('(?:(a)|b)+', 'bbb') == '(None,)'
    // python: __import__('re').search('(?P<optional>x)?(?P<letter>a)', 'a').groups() == (None, 'a')
    assert capture_tuple('(?P<optional>x)?(?P<letter>a)', 'a') == "(None, 'a')"
    // python: __import__('re').search('(a*)b', 'b').groups() == ('',)
    assert capture_tuple('(a*)b', 'b') == "('',)"
    // python: __import__('re').search('(a*)*b', 'b').groups() == ('',)
    assert capture_tuple('(a*)*b', 'b') == "('',)"
    // python: __import__('re').search('((a)|(b))+', 'ab').groups() == ('b', 'a', 'b')
    assert capture_tuple('((a)|(b))+', 'ab') == "('b', 'a', 'b')"
}

fn test_optional_capture_offsets_and_names() {
    p := compile('(?P<maybe>x)?(a)', 0) or { panic(err.msg()) }
    m := p.search('za') or { panic('no match') }
    // python: __import__('re').search('(?P<maybe>x)?(a)', 'za').group('maybe') is None
    assert (m.group_name('maybe') or { panic(err.msg()) }) is pyrt.NoneType
    // python: __import__('re').search('(?P<maybe>x)?(a)', 'za').span(1) == (-1, -1)
    absent := m.span(1) or { panic(err.msg()) }
    assert absent.start == -1 && absent.end == -1
    // python: __import__('re').search('(?P<maybe>x)?(a)', 'za').start(1) == -1
    assert (m.start(1) or { panic(err.msg()) }) == -1
    // python: __import__('re').search('(?P<maybe>x)?(a)', 'za').end(1) == -1
    assert (m.end(1) or { panic(err.msg()) }) == -1
    // python: __import__('re').search('(?P<maybe>x)?(a)', 'za').span(2) == (1, 2)
    present := m.span(2) or { panic(err.msg()) }
    assert present.start == 1 && present.end == 2
    // python: __import__('re').search('(?P<maybe>x)?(a)', 'za').groupdict() == {'maybe': None}
    names := m.groupdict()
    assert names['maybe'] is pyrt.NoneType
    // python: __import__('re').search('(a)(a)', 'aa').span(2) == (1, 2)
    duplicates := compile('(a)(a)', 0) or { panic(err.msg()) }
    duplicate_match := duplicates.search('aa') or { panic('no match') }
    second := duplicate_match.span(2) or { panic(err.msg()) }
    assert second.start == 1 && second.end == 2
    // python: __import__('re').search('(é)?(a)', 'éa').span(2) == (1, 2)
    unicode_pattern := compile('(é)?(a)', 0) or { panic(err.msg()) }
    unicode_match := unicode_pattern.search('éa') or { panic('no match') }
    unicode_span := unicode_match.span(2) or { panic(err.msg()) }
    assert unicode_span.start == 1 && unicode_span.end == 2
}

fn test_capture_backtracking_and_consumers() {
    // python: __import__('re').search('(a+)(a)', 'aaaa').groups() == ('aaa', 'a')
    assert capture_tuple('(a+)(a)', 'aaaa') == "('aaa', 'a')"
    // python: __import__('re').search('(a+?)(a)', 'aaaa').groups() == ('a', 'a')
    assert capture_tuple('(a+?)(a)', 'aaaa') == "('a', 'a')"
    // python: __import__('re').search('(a|ab)c', 'abc').groups() == ('ab',)
    assert capture_tuple('(a|ab)c', 'abc') == "('ab',)"
    // python: __import__('re').search('(a){1,3}a', 'aaa').groups() == ('a',)
    assert capture_tuple('(a){1,3}a', 'aaa') == "('a',)"
    // python: __import__('re').search(r'(a)?b\1', 'aba').groups() == ('a',)
    assert capture_tuple('(a)?b\\1', 'aba') == "('a',)"
    // python: __import__('re').search(r'(a)?b\1', 'b') is None
    unmatched_backref := compile('(a)?b\\1', 0) or { panic(err.msg()) }
    assert unmatched_backref.search('b') == none
    p := compile('(x)?(a)', 0) or { panic(err.msg()) }
    // python: __import__('re').compile('(x)?(a)').fullmatch('a').groups() == (None, 'a')
    full := p.fullmatch('a') or { panic('no match') }
    assert pyrt.repr(pyrt.Value(pyrt.new_tuple(full.groups()))) == "(None, 'a')"
    // python: __import__('re').compile('(x)?(a)').match('za') is None
    assert p.match_('za') == none
    // python: __import__('re').findall('(x)?(a)', 'a xa') == [('', 'a'), ('x', 'a')]
    assert pyrt.repr(pyrt.Value(pyrt.new_list(p.findall('a xa')))) == "[('', 'a'), ('x', 'a')]"
    // python: __import__('re').sub('(x)?(a)', r'<\1:\2>', 'a xa') == '<:a> <x:a>'
    assert (p.sub('<\\1:\\2>', 'a xa', 0) or { panic(err.msg()) }) == '<:a> <x:a>'
    // python: __import__('re').split('(x)?a', 'zaq') == ['z', None, 'q']
    splitter := compile('(x)?a', 0) or { panic(err.msg()) }
    assert pyrt.repr(pyrt.Value(pyrt.new_list(splitter.split('zaq', 0) or { panic(err.msg()) }))) == "['z', None, 'q']"
    // python: [(m.group(0), m.span(0)) for m in __import__('re').finditer('(a*?)', 'a')] == [('', (0, 0)), ('a', (0, 1)), ('', (1, 1))]
    lazy := compile('(a*?)', 0) or { panic(err.msg()) }
    found := lazy.finditer('a')
    assert found.len == 3 && found[0].start_byte == 0 && found[0].end_byte == 0 && found[1].end_byte == 1 && found[2].start_byte == 1
}

fn test_capture_recovery_limits_are_explicit() {
    mut rejected := false
    _ = compile('(?=(a))a', 0) or {
        rejected = pyrt.caught(err, 'NotImplementedError') != none
        Pattern{}
    }
    // runtime: The supplied wrapper lacks safe unset-capture/offset access. Unsupported capturing lookaround is rejected, not silently treated as no-match.
    assert rejected
}

fn test_capture_free_empty_match_progression() {
    lazy := compile('a*?', 0) or { panic(err.msg()) }
    found := lazy.finditer('a')
    // python: [(m.group(0), m.span(0)) for m in __import__('re').finditer('a*?', 'a')] == [('', (0, 0)), ('a', (0, 1)), ('', (1, 1))]
    assert found.len == 3 && found[0].start_byte == 0 && found[0].end_byte == 0 && found[1].end_byte == 1 && found[2].start_byte == 1
    // python: __import__('re').sub('a*?', '<>', 'a') == '<><><>'
    assert (lazy.sub('<>', 'a', 0) or { panic(err.msg()) }) == '<><><>'
}
