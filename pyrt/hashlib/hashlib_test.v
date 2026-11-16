module hashlib

fn test_hashlib_known_vectors() {
    // python: __import__('hashlib').sha256(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    assert sha256([u8(97), 98, 99]).hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    // python: __import__('hashlib').md5(b'abc').hexdigest() == '900150983cd24fb0d6963f7d28e17f72'
    assert md5([u8(97), 98, 99]).hexdigest() == '900150983cd24fb0d6963f7d28e17f72'
    // python: __import__('hashlib').sha1(b'abc').hexdigest() == 'a9993e364706816aba3e25717850c26c9cd0d89d'
    assert sha1([u8(97), 98, 99]).hexdigest() == 'a9993e364706816aba3e25717850c26c9cd0d89d'
    // python: __import__('hashlib').sha512(b'abc').digest_size == 64
    assert sha512([]u8{}).digest_size == 64
    // python: __import__('hashlib').sha384(b'abc').digest_size == 48
    assert sha384([]u8{}).digest_size == 48
}

fn test_hashlib_incremental_and_copy() {
    h := sha256([]u8{})
    h.update_str('a')
    h.update([u8(98), 99])
    // python: (__import__('hashlib').sha256(b'abc').hexdigest()) == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    assert h.hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    second := h.copy()
    second.update_str('d')
    // python: __import__('hashlib').sha256(b'abcd').digest_size == 32
    assert second.digest().len == 32
    // python: __import__('hashlib').sha256(b'abc').hexdigest() != __import__('hashlib').sha256(b'abcd').hexdigest()
    assert h.hexdigest() != second.hexdigest()
    // python: __import__('hashlib').sha256().block_size == 64
    assert h.block_size == 64
    // python: __import__('hashlib').sha256().name == 'sha256'
    assert h.name == 'sha256'
}

fn test_hashlib_digest_repeat_and_bad_name() {
    h := sha256([u8(97)])
    one := h.digest()
    two := h.digest()
    // python: __import__('hashlib').sha256(b'a').digest() == __import__('hashlib').sha256(b'a').digest()
    assert one == two
    mut message := ''
    _ = new('unknown-algorithm', []u8{}) or { message = err.msg(); sha256([]u8{}) }
    // python: error_text(lambda: __import__('hashlib').new('unknown-algorithm')).startswith('ValueError|unsupported hash type')
    assert message.contains('unsupported hash type')
}
