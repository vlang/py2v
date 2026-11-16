module uuid

import crypto.rand
import encoding.hex
import pyrt

pub struct UUID {
pub:
    hex string
    bytes []u8
    version int
}

fn digit_hex(ch u8) int {
    if ch >= 48 && ch <= 57 { return int(ch) - 48 }
    if ch >= 65 && ch <= 70 { return int(ch) - 55 }
    if ch >= 97 && ch <= 102 { return int(ch) - 87 }
    return -1
}

fn hex_lower(text string) !string {
    mut result := ''
    for i in 0 .. text.len {
        ch := text[i]
        n := digit_hex(ch)
        if n < 0 { return pyrt.raise('ValueError', 'badly formed hexadecimal UUID string') }
        alphabet := '0123456789abcdef'
        result = result + alphabet[n .. n + 1]
    }
    return result
}

fn uuid_from_bytes(raw []u8) UUID {
    encoded := hex.encode(raw, hex.EncodeParams{})
    version := int(raw[6] >> 4)
    return UUID{hex: encoded, bytes: raw.clone(), version: version}
}

pub fn new_uuid(text string) !UUID {
    mut raw := text
    if raw.len >= 9 && raw[0 .. 9] == 'urn:uuid:' { raw = raw[9 .. raw.len] }
    if raw.len >= 2 && raw[0] == 123 && raw[raw.len - 1] == 125 {
        raw = raw[1 .. raw.len - 1]
    }
    mut compact := ''
    for i in 0 .. raw.len {
        if raw[i] != 45 { compact = compact + raw[i .. i + 1] }
    }
    if compact.len != 32 { return pyrt.raise('ValueError', 'badly formed hexadecimal UUID string') }
    clean := hex_lower(compact)!
    data := hex.decode(clean) or { return pyrt.raise('ValueError', 'badly formed hexadecimal UUID string') }
    return uuid_from_bytes(data)
}

pub fn uuid4() !UUID {
    mut data := rand.bytes(16)!
    data[6] = (data[6] & u8(0x0f)) | u8(0x40)
    data[8] = (data[8] & u8(0x3f)) | u8(0x80)
    return uuid_from_bytes(data)
}

pub fn (u UUID) str() string {
    return u.hex[0 .. 8] + '-' + u.hex[8 .. 12] + '-' +
        u.hex[12 .. 16] + '-' + u.hex[16 .. 20] + '-' + u.hex[20 .. 32]
}

pub fn (u UUID) eq(other UUID) bool { return u.hex == other.hex }
