module hashlib

import crypto.md5 as cmd5
import crypto.sha1 as csha1
import crypto.sha256 as csha256
import crypto.sha512 as csha512
import encoding.hex
import pyrt

// Replay-based digest: only the supplied one-shot crypto APIs are required.
// Repeated digest()/copy() are correct but the entire input stays in memory.
pub struct Hash {
pub:
    name string
    digest_size int
    block_size int
mut:
    data []u8
}

fn make_hash(name string, data []u8) !&Hash {
    mut normalized := ''
    for i in 0 .. name.len {
        ch := name[i]
        if ch >= 65 && ch <= 90 { normalized = normalized + rune(int(ch) + 32).str() }
        else { normalized = normalized + name[i .. i + 1] }
    }
    if normalized == 'sha-256' { normalized = 'sha256' }
    if normalized == 'sha-1' { normalized = 'sha1' }
    if normalized == 'sha-512' { normalized = 'sha512' }
    if normalized == 'sha-384' { normalized = 'sha384' }
    mut size := 0
    mut block := 64
    match normalized {
        'sha256' { size = 32 }
        'sha1' { size = 20 }
        'md5' { size = 16 }
        'sha512' { size = 64; block = 128 }
        'sha384' { size = 48; block = 128 }
        else { return pyrt.raise('ValueError', 'unsupported hash type ${name}') }
    }
    return &Hash{name: normalized, digest_size: size, block_size: block, data: data.clone()}
}

pub fn new(name string, data []u8) !&Hash { return make_hash(name, data)! }
pub fn sha256(data []u8) &Hash { return make_hash('sha256', data) or { panic(err.msg()) } }
pub fn sha1(data []u8) &Hash { return make_hash('sha1', data) or { panic(err.msg()) } }
pub fn md5(data []u8) &Hash { return make_hash('md5', data) or { panic(err.msg()) } }
pub fn sha512(data []u8) &Hash { return make_hash('sha512', data) or { panic(err.msg()) } }
pub fn sha384(data []u8) &Hash { return make_hash('sha384', data) or { panic(err.msg()) } }

pub fn (h &Hash) update(data []u8) {
    unsafe { h.data << data }
}

pub fn (h &Hash) update_str(text string) {
    mut data := []u8{cap: text.len}
    for i in 0 .. text.len { data << text[i] }
    h.update(data)
}

pub fn (h &Hash) digest() []u8 {
    return match h.name {
        'sha256' { csha256.sum256(h.data) }
        'sha1' { csha1.sum(h.data) }
        'md5' { cmd5.sum(h.data) }
        'sha512' { csha512.sum512(h.data) }
        'sha384' { csha512.sum384(h.data) }
        else { []u8{} }
    }
}

pub fn (h &Hash) hexdigest() string {
    return hex.encode(h.digest(), hex.EncodeParams{})
}

pub fn (h &Hash) copy() &Hash {
    return &Hash{name: h.name, digest_size: h.digest_size,
        block_size: h.block_size, data: h.data.clone()}
}
