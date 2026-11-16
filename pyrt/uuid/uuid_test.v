module uuid

fn test_uuid_parse_roundtrip_and_properties() {
    a := new_uuid('550e8400-e29b-41d4-a716-446655440000') or { panic(err.msg()) }
    // python: str(__import__('uuid').UUID('550E8400-E29B-41D4-A716-446655440000')) == '550e8400-e29b-41d4-a716-446655440000'
    assert a.str() == '550e8400-e29b-41d4-a716-446655440000'
    // python: __import__('uuid').UUID('550e8400-e29b-41d4-a716-446655440000').hex == '550e8400e29b41d4a716446655440000'
    assert a.hex == '550e8400e29b41d4a716446655440000'
    // python: __import__('uuid').UUID('550e8400-e29b-41d4-a716-446655440000').version == 4
    assert a.version == 4
    // python: len(__import__('uuid').UUID('550e8400-e29b-41d4-a716-446655440000').bytes) == 16
    assert a.bytes.len == 16
}

fn test_uuid4_version_and_variant() {
    u := uuid4() or { panic(err.msg()) }
    // python: len(str(__import__('uuid').uuid4())) == 36
    assert u.str().len == 36
    // python: __import__('uuid').uuid4().version == 4
    assert u.version == 4
    // python: (__import__('uuid').uuid4().bytes[8] & 0xc0) == 0x80
    assert (u.bytes[8] & u8(0xc0)) == u8(0x80)
}

fn test_uuid_invalid_text() {
    mut message := ''
    _ = new_uuid('malformed') or { message = err.msg(); UUID{} }
    // python: error_text(lambda: __import__('uuid').UUID('malformed')) == 'ValueError|badly formed hexadecimal UUID string'
    assert message == 'badly formed hexadecimal UUID string'
}
