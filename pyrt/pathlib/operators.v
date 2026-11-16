module pathlib

// Plain method routes avoid cross-module V operator resolution.
pub fn (p Path) divide(other Path) Path { return p.joinpath(other.str()) }
pub fn (p Path) eq(other Path) bool { return p.str() == other.str() }
pub fn (p Path) compare(other Path) int {
    a := p.parts()
    b := other.parts()
    mut limit := a.len
    if b.len < limit { limit = b.len }
    for i in 0 .. limit {
        if a[i] < b[i] { return -1 }
        if a[i] > b[i] { return 1 }
    }
    return if a.len < b.len { -1 } else if a.len > b.len { 1 } else { 0 }
}
pub fn (p Path) lt(other Path) bool { return p.compare(other) < 0 }
pub fn (p Path) le(other Path) bool { return p.compare(other) <= 0 }
pub fn (p Path) gt(other Path) bool { return p.compare(other) > 0 }
pub fn (p Path) ge(other Path) bool { return p.compare(other) >= 0 }
pub fn (p Path) bool_() bool { return true }
