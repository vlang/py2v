module random

import rand as vrand
import pyrt

// This delegates to V's global PRNG. A numeric seed is NOT CPython's MT19937
// seed expansion, and sequences for the same seed are intentionally different.
pub fn seed(value i64) {
    vrand.seed([u32(value), u32(value >> 32)])
}

pub fn random() f64 { return vrand.f64() }

pub fn randint(lower int, upper int) !int {
    if lower > upper { return pyrt.raise('ValueError', 'empty range for randrange()') }
    if upper == 9223372036854775807 {
        return pyrt.raise('OverflowError', 'upper bound is too large for V range helper')
    }
    return vrand.int_in_range(lower, upper + 1)!
}

pub fn uniform(lower f64, upper f64) f64 {
    return lower + (upper - lower) * vrand.f64()
}

pub fn choice(values []pyrt.Value) !pyrt.Value {
    if values.len == 0 { return pyrt.raise('IndexError', 'Cannot choose from an empty sequence') }
    return values[vrand.intn(values.len)!]
}

pub fn shuffle(mut values []pyrt.Value) ! {
    // The documented V shuffle API needs an unlisted config struct; use
    // the Fisher-Yates algorithm with its documented intn() primitive.
    mut i := values.len - 1
    for i > 0 {
        j := vrand.intn(i + 1)!
        old := values[i]
        values[i] = values[j]
        values[j] = old
        i = i - 1
    }
}

pub fn choices(values []pyrt.Value, k int) ![]pyrt.Value {
    if k < 0 { return pyrt.raise('ValueError', 'k must be a non-negative integer') }
    mut result := []pyrt.Value{}
    for _ in 0 .. k { result << choice(values)! }
    return result
}
