module base64

fn test_base64_standard_and_urlsafe() {
    // python: __import__('base64').b64encode(b'hello') == b'aGVsbG8='
    assert b64encode([u8(104), 101, 108, 108, 111]) == [u8(97), 71, 86, 115, 98, 71, 56, 61]
    // python: __import__('base64').b64decode(b'aGVsbG8=') == b'hello'
    assert b64decode([u8(97),71,86,115,98,71,56,61], DecodeOptions{}) or { []u8{} } == [u8(104),101,108,108,111]
    // python: __import__('base64').urlsafe_b64encode(b'\xff\xff') == b'__8='
    assert urlsafe_b64encode([u8(255),255]) == [u8(95),95,56,61]
    // python: __import__('base64').urlsafe_b64decode(b'__8=') == b'\xff\xff'
    assert urlsafe_b64decode([u8(95),95,56,61]) or { []u8{} } == [u8(255),255]
}

fn test_base64_strict_errors() {
    mut error_text := ''
    _ = b64decode_str('@@@', validate: true) or { error_text = err.msg(); []u8{} }
    // python: error_text(lambda: __import__('base64').b64decode('@@@', validate=True)) == 'Error|Only base64 data is allowed'
    assert error_text.contains('base64 data')
}
