module base64

import encoding.base64 as vbase64
import pyrt

@[params]
pub struct DecodeOptions {
pub:
    validate bool
}

fn ascii_bytes(text string) []u8 {
    mut out := []u8{}
    for i in 0 .. text.len { out << text[i] }
    return out
}

pub fn b64encode(data []u8) []u8 { return ascii_bytes(vbase64.encode(data)) }

pub fn urlsafe_b64encode(data []u8) []u8 {
    // Avoid relying on whether the V URL encoder retains padding.
    mut encoded := b64encode(data)
    for i in 0 .. encoded.len {
        if encoded[i] == 43 { encoded[i] = u8(45) }
        if encoded[i] == 47 { encoded[i] = u8(95) }
    }
    return encoded
}

fn decode_checked(data []u8, validate bool, urlsafe bool) ![]u8 {
    pyrt.register_exception('binascii.Error', ['ValueError'])
    mut text := ''
    for b in data {
        ch := if urlsafe && b == 45 { u8(43) } else if urlsafe && b == 95 { u8(47) } else { b }
        valid := (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) ||
            (ch >= 48 && ch <= 57) || ch == 43 || ch == 47 || ch == 61
        if !valid {
            if validate { return pyrt.raise('binascii.Error', 'Only base64 data is allowed') }
            continue
        }
        text = text + rune(int(ch)).str()
    }
    // Validate the common RFC 4648 alphabet and trailing padding. CPython's
    // newer surplus-data and discontinuous-padding behavior can differ.
    mut first_padding := -1
    for i in 0 .. text.len {
        if text[i] == 61 {
            if first_padding < 0 { first_padding = i }
        } else if first_padding >= 0 && validate {
            return pyrt.raise('binascii.Error', 'Excess data after padding')
        }
    }
    if first_padding >= 0 {
        // Non-strict CPython ignores nonalphabet suffix in some cases.
        for i in first_padding .. text.len {
            if text[i] != 61 { return pyrt.raise('binascii.Error', 'Incorrect padding') }
        }
    }
    non_padding := if first_padding < 0 { text.len } else { first_padding }
    if non_padding % 4 == 1 {
        return pyrt.raise('binascii.Error',
            'Invalid base64-encoded string: number of data characters (${non_padding}) cannot be 1 more than a multiple of 4')
    }
    if non_padding % 4 != 0 && text.len % 4 != 0 {
        return pyrt.raise('binascii.Error', 'Incorrect padding')
    }
    if validate && text.len % 4 != 0 {
        return pyrt.raise('binascii.Error', 'Incorrect padding')
    }
    return vbase64.decode(text)
}

pub fn b64decode(data []u8, opts DecodeOptions) ![]u8 {
    return decode_checked(data, opts.validate, false)!
}

pub fn urlsafe_b64decode(data []u8) ![]u8 {
    return decode_checked(data, false, true)!
}

pub fn b64encode_str(data string) []u8 { return b64encode(ascii_bytes(data)) }

pub fn b64decode_str(data string, opts DecodeOptions) ![]u8 {
    return b64decode(ascii_bytes(data), opts)!
}

pub fn urlsafe_b64decode_str(data string) ![]u8 {
    return urlsafe_b64decode(ascii_bytes(data))!
}
