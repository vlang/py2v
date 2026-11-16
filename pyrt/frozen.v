module pyrt

// The immutable set uses the old &Set Value variant with frozen=true.
// The public mutable backing fields are a legacy compatibility loophole:
// never mutate .items or .index directly on a frozen set.
pub fn frozen_union(a Value, b Value) !Value {
    if a is &Set {
        mut out := new_set(a.items)!
        for item in iter(b)! { out.add(item)! }
        return frozenset_of(out.items)!
    }
    return raise('TypeError', "unsupported operand type(s) for |: '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_intersection(a Value, b Value) !Value {
    if a is &Set {
        mut out := []Value{}
        for item in a.items { if contains(b, item)! { out << item } }
        return frozenset_of(out)!
    }
    return raise('TypeError', "unsupported operand type(s) for &: '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_difference(a Value, b Value) !Value {
    if a is &Set {
        mut out := []Value{}
        for item in a.items { if !contains(b, item)! { out << item } }
        return frozenset_of(out)!
    }
    return raise('TypeError', "unsupported operand type(s) for -: '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_issubset(a Value, b Value) !bool {
    if a is &Set {
        for item in a.items { if !contains(b, item)! { return false } }
        return true
    }
    return raise('TypeError', "'${type_name(a)}' is not a set")
}

pub fn frozen_symmetric_difference(a Value, b Value) !Value {
    if a is &Set {
        other := new_set(iter(b)!)!
        mut result := []Value{}
        for item in a.items { if !contains(Value(other), item)! { result << item } }
        for item in other.items { if !contains(a, item)! { result << item } }
        return frozenset_of(result)!
    }
    return raise('TypeError', "unsupported operand type(s) for ^: '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_le(a Value, b Value) !bool {
    if b is &Set { return frozen_issubset(a, b)! }
    return raise('TypeError', "'<=' not supported between instances of '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_lt(a Value, b Value) !bool {
    if b is &Set {
        smaller := frozen_issubset(a, b)!
        return smaller && len_(a)! < len_(b)!
    }
    return raise('TypeError', "'<' not supported between instances of '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_ge(a Value, b Value) !bool {
    if b is &Set { return frozen_issubset(b, a)! }
    return raise('TypeError', "'>=' not supported between instances of '${type_name(a)}' and '${type_name(b)}'")
}

pub fn frozen_gt(a Value, b Value) !bool {
    if b is &Set {
        greater := frozen_issubset(b, a)!
        return greater && len_(a)! > len_(b)!
    }
    return raise('TypeError', "'>' not supported between instances of '${type_name(a)}' and '${type_name(b)}'")
}
