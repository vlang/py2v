module secrets

import crypto.rand
import crypto.hmac
import encoding.hex
import pyrt.base64 as pybase64
import pyrt

pub fn token_bytes(n int) ![]u8 {
    if n < 0 { return pyrt.raise('ValueError', 'negative argument not allowed') }
    return rand.bytes(n)!
}

pub fn token_hex(n int) !string {
    return hex.encode(token_bytes(n)!, hex.EncodeParams{})
}

pub fn token_urlsafe(n int) !string {
    raw := pybase64.urlsafe_b64encode(token_bytes(n)!)
    mut out := ''
    for c in raw { if c != 61 { out = out + rune(int(c)).str() } }
    return out
}

pub fn compare_digest(a []u8, b []u8) bool { return hmac.equal(a, b) }

pub fn compare_digest_str(a string, b string) !bool {
    mut left := []u8{}
    mut right := []u8{}
    for i in 0 .. a.len {
        if a[i] >= 128 { return pyrt.raise('TypeError', 'comparing strings with non-ASCII characters is not supported') }
        left << a[i]
    }
    for i in 0 .. b.len {
        if b[i] >= 128 { return pyrt.raise('TypeError', 'comparing strings with non-ASCII characters is not supported') }
        right << b[i]
    }
    return hmac.equal(left, right)
}
