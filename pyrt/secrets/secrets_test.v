module secrets

fn test_secrets_lengths_and_comparison() {
    // python: len(__import__('secrets').token_bytes(16)) == 16
    assert (token_bytes(16) or { []u8{} }).len == 16
    // python: len(__import__('secrets').token_hex(8)) == 16
    assert (token_hex(8) or { '' }).len == 16
    // python: len(__import__('secrets').token_urlsafe(8)) == 11
    assert (token_urlsafe(8) or { '' }).len == 11
    // python: __import__('secrets').compare_digest(b'abc', b'abc')
    assert compare_digest([u8(97),98,99], [u8(97),98,99])
    // python: not __import__('secrets').compare_digest(b'abc', b'abd')
    assert !compare_digest([u8(97),98,99], [u8(97),98,100])
    // python: __import__('secrets').compare_digest('abc', 'abc')
    assert compare_digest_str('abc', 'abc') or { false }
}
