module collections

import pyrt

pub fn (c &Counter) contains(key pyrt.Value) !bool { return pyrt.contains(pyrt.Value(c.backing), key)! }
pub fn (c &Counter) bool_() bool { return c.len() > 0 }
pub fn (c &Counter) eq(other &Counter) !bool {
    for key in c.backing.keys { if !pyrt.eq(c.get_item(key)!, other.get_item(key)!) { return false } }
    for key in other.backing.keys { if !pyrt.eq(c.get_item(key)!, other.get_item(key)!) { return false } }
    return true
}
pub fn (c &Counter) le(other &Counter) !bool {
    for key in c.backing.keys {
        ordered := pyrt.le(c.get_item(key)!, other.get_item(key)!)!
        if !ordered { return false }
    }
    for key in other.backing.keys {
        ordered := pyrt.le(c.get_item(key)!, other.get_item(key)!)!
        if !ordered { return false }
    }
    return true
}
pub fn (c &Counter) lt(other &Counter) !bool {
    ordered := c.le(other)!
    equal := c.eq(other)!
    return ordered && !equal
}
pub fn (c &Counter) ge(other &Counter) !bool { return other.le(c)! }
pub fn (c &Counter) gt(other &Counter) !bool { return other.lt(c)! }
pub fn (c &Counter) str() string {
    if c.len() == 0 { return 'Counter()' }
    items := c.most_common(none) or { c.items() or { return 'Counter()' } }
    mut parts := []string{}
    for item in items {
        pair := pyrt.iter(item) or { []pyrt.Value{} }
        if pair.len < 2 { continue }
        parts << pyrt.repr(pair[0]) + ': ' + pyrt.repr(pair[1])
    }
    return 'Counter({' + parts.join(', ') + '})'
}
