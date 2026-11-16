module pyrt

// Instance supplies getattr but NOT field enumeration. py2v must supply the
// dataclass's declared field names (in declaration order); that is the only
// route for arbitrary translated Instance implementations in this interface.
fn asdict_copy(v Value, depth int) !Value {
    if depth > 256 { return raise('RecursionError', 'maximum recursion depth exceeded') }
    if v is &List {
        mut result := []Value{}
        for item in v.items { result << asdict_copy(item, depth + 1)! }
        return Value(new_list(result))
    }
    if v is &Tuple {
        mut result := []Value{}
        for item in iter(v)! { result << asdict_copy(item, depth + 1)! }
        return Value(new_tuple(result))
    }
    if v is &Dict {
        result := new_dict()
        for key in v.keys {
            item := getitem(Value(v), key)!
            setitem(Value(result), asdict_copy(key, depth + 1)!, asdict_copy(item, depth + 1)!)!
        }
        return Value(result)
    }
    if v is &Set {
        mut members := []Value{}
        for member in v.items { members << asdict_copy(member, depth + 1)! }
        if v.frozen { return frozenset_of(members)! }
        return Value(new_set(members)!)
    }
    // Nested Instance fields cannot be enumerated without compiler metadata.
    // This is a shallow value copy for scalar and unknown Instance fields.
    return v
}

pub fn dataclass_asdict(v Value, names []string) !Value {
    if !(v is Instance) {
        return raise('TypeError', 'asdict() should be called on dataclass instances')
    }
    result := new_dict()
    for name in names {
        item := getattr(v, name)!
        setitem(Value(result), Value(name), asdict_copy(item, 1)!)!
    }
    return Value(result)
}

pub fn dataclass_asdict_object(o &Object) !Value {
    result := new_dict()
    for name, item in o.fields {
        setitem(Value(result), Value(name), asdict_copy(item, 1)!)!
    }
    return Value(result)
}
