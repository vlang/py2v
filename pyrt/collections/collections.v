module collections

import pyrt

// There is no mapping protocol on pyrt.Instance in the pinned core.
// DefaultDict/Counter therefore expose typed get_item/set_item and an
// Instance boxed view for identity/type handling. Their boxed values are NOT
// subscriptable by pyrt.getitem; see compatibility notes.

pub struct Entry {
pub:
    key pyrt.Value
    value pyrt.Value
}

fn missing_attribute(class_name string, name string) IError {
    return pyrt.raise('AttributeError', "'${class_name}' object has no attribute '${name}'")
}

fn missing_key(key pyrt.Value) IError {
    return pyrt.key_error(key)
}

fn fresh_value(factory string) !pyrt.Value {
    if factory == 'int' { return pyrt.Value(i64(0)) }
    if factory == 'float' { return pyrt.Value(f64(0)) }
    if factory == 'str' { return pyrt.Value('') }
    if factory == 'list' { return pyrt.Value(pyrt.new_list([]pyrt.Value{})) }
    if factory == 'dict' { return pyrt.Value(pyrt.new_dict()) }
    if factory == 'set' {
        items := pyrt.new_set([]pyrt.Value{})!
        return pyrt.Value(items)
    }
    return pyrt.raise('TypeError', 'first argument must be callable or None')
}

pub struct DefaultDict {
mut:
    backing &pyrt.Dict
    factory_name string
    factory_callback fn () pyrt.Value = unsafe { nil }
    uses_callback bool
    identity i64
}

pub fn defaultdict(factory string) !&DefaultDict {
    if factory != '' && factory !in ['int', 'float', 'str', 'list', 'dict', 'set'] {
        return pyrt.raise('TypeError', 'first argument must be callable or None')
    }
    return &DefaultDict{backing: pyrt.new_dict(), factory_name: factory,
        identity: pyrt.identity_token()}
}

pub fn defaultdict_fn(callback fn () pyrt.Value) &DefaultDict {
    return &DefaultDict{backing: pyrt.new_dict(), factory_callback: callback,
        uses_callback: true, identity: pyrt.identity_token()}
}

pub fn (d &DefaultDict) class_name() string { return 'defaultdict' }
pub fn (d &DefaultDict) pyrt_identity() i64 { return d.identity }
pub fn (d &DefaultDict) as_value() pyrt.Value { return pyrt.Value(pyrt.Instance(d)) }
pub fn (d &DefaultDict) as_dict() &pyrt.Dict { return d.backing }
pub fn (d &DefaultDict) len() int { return d.backing.keys.len }
pub fn (d &DefaultDict) keys() []pyrt.Value { return d.backing.keys.clone() }

pub fn (d &DefaultDict) default_factory() pyrt.Value {
    if d.uses_callback { return pyrt.Value('<V callback>') }
    if d.factory_name == '' { return pyrt.none_ }
    return pyrt.Value(d.factory_name)
}

pub fn (d &DefaultDict) getattr(name string) !pyrt.Value {
    if name == 'default_factory' { return d.default_factory() }
    return missing_attribute('defaultdict', name)
}

pub fn (mut d DefaultDict) setattr(name string, value pyrt.Value) ! {
    if name == 'default_factory' {
        if value is pyrt.NoneType { d.factory_name = ''; d.uses_callback = false; return }
        if value is string {
            if value in ['int', 'float', 'str', 'list', 'dict', 'set'] {
                d.factory_name = value
                d.uses_callback = false
                return
            }
        }
        return pyrt.raise('TypeError', 'first argument must be callable or None')
    }
    return missing_attribute('defaultdict', name)
}

pub fn (d &DefaultDict) get_item(key pyrt.Value) !pyrt.Value {
    hash := pyrt.hash_key(key)!
    if hash in d.backing.values { return d.backing.values[hash] or { return missing_key(key) } }
    if !d.uses_callback && d.factory_name == '' { return missing_key(key) }
    created := if d.uses_callback { d.factory_callback() } else { fresh_value(d.factory_name)! }
    pyrt.setitem(pyrt.Value(d.backing), key, created)!
    return created
}

pub fn (d &DefaultDict) get(key pyrt.Value, default_value pyrt.Value) !pyrt.Value {
    hash := pyrt.hash_key(key)!
    return d.backing.values[hash] or { default_value }
}

pub fn (d &DefaultDict) set_item(key pyrt.Value, value pyrt.Value) ! {
    pyrt.setitem(pyrt.Value(d.backing), key, value)!
}

pub fn (d &DefaultDict) del_item(key pyrt.Value) ! {
    pyrt.delitem(pyrt.Value(d.backing), key)!
}

pub fn (d &DefaultDict) items() ![]pyrt.Value {
    mut result := []pyrt.Value{}
    for key in d.backing.keys {
        value := pyrt.getitem(pyrt.Value(d.backing), key)!
        result << pyrt.Value(pyrt.new_tuple([key, value]))
    }
    return result
}

pub fn (d &DefaultDict) clear() {
    unsafe {
        d.backing.keys = []pyrt.Value{}
        d.backing.values = map[string]pyrt.Value{}
    }
}

// Counter retains zero/negative counts, like CPython. The backing dictionary
// holds counts as values; keys use pyrt's numeric-equivalence hashing.
pub struct Counter {
mut:
    backing &pyrt.Dict
    identity i64
}

pub fn counter(source pyrt.Value) !&Counter {
    result := &Counter{backing: pyrt.new_dict(), identity: pyrt.identity_token()}
    if source !is pyrt.NoneType { result.update(source)! }
    return result
}

pub fn (c &Counter) class_name() string { return 'Counter' }
pub fn (c &Counter) pyrt_identity() i64 { return c.identity }
pub fn (c &Counter) as_value() pyrt.Value { return pyrt.Value(pyrt.Instance(c)) }
pub fn (c &Counter) as_dict() &pyrt.Dict { return c.backing }
pub fn (c &Counter) len() int { return c.backing.keys.len }
pub fn (c &Counter) keys() []pyrt.Value { return c.backing.keys.clone() }
pub fn (c &Counter) getattr(name string) !pyrt.Value { return missing_attribute('Counter', name) }
pub fn (mut c Counter) setattr(name string, value pyrt.Value) ! {
    _ = value
    return missing_attribute('Counter', name)
}

pub fn (c &Counter) get_item(key pyrt.Value) !pyrt.Value {
    hash := pyrt.hash_key(key)!
    return c.backing.values[hash] or { pyrt.Value(i64(0)) }
}

pub fn (c &Counter) set_item(key pyrt.Value, count pyrt.Value) ! {
    pyrt.setitem(pyrt.Value(c.backing), key, count)!
}

pub fn (c &Counter) del_item(key pyrt.Value) ! {
    // Unlike dict, deleting an absent Counter key is harmless.
    hash := pyrt.hash_key(key)!
    if hash in c.backing.values { pyrt.delitem(pyrt.Value(c.backing), key)! }
}

pub fn (c &Counter) increment(key pyrt.Value, amount pyrt.Value) ! {
    before := c.get_item(key)!
    after := pyrt.add(before, amount)!
    c.set_item(key, after)!
}

pub fn (c &Counter) update(source pyrt.Value) ! {
    if source is &pyrt.Dict {
        for key in source.keys {
            val := pyrt.getitem(pyrt.Value(source), key)!
            c.increment(key, val)!
        }
        return
    }
    for key in pyrt.iter(source)! { c.increment(key, pyrt.Value(i64(1)))! }
}

pub fn (c &Counter) update_counter(other &Counter) ! {
    for key in other.backing.keys { c.increment(key, other.get_item(key)!)! }
}

pub fn (c &Counter) subtract(source pyrt.Value) ! {
    if source is &pyrt.Dict {
        for key in source.keys {
            val := pyrt.getitem(pyrt.Value(source), key)!
            c.increment(key, pyrt.neg(val)!)!
        }
        return
    }
    for key in pyrt.iter(source)! { c.increment(key, pyrt.Value(i64(-1)))! }
}

pub fn (c &Counter) elements() ![]pyrt.Value {
    mut result := []pyrt.Value{}
    for key in c.backing.keys {
        raw := c.get_item(key)!
        if raw !is i64 && raw !is int && raw !is bool {
            return pyrt.raise('TypeError', "'${pyrt.type_name(raw)}' object cannot be interpreted as an integer")
        }
        count := pyrt.as_int(raw)!
        if count > 1000000 { return pyrt.raise('OverflowError', 'Counter.elements() exceeds runtime expansion limit') }
        for _ in 0 .. int(count) { result << key }
    }
    return result
}

pub fn (c &Counter) items() ![]pyrt.Value {
    mut result := []pyrt.Value{}
    for key in c.backing.keys {
        result << pyrt.Value(pyrt.new_tuple([key, c.get_item(key)!]))
    }
    return result
}

pub fn (c &Counter) most_common(n ?int) ![]pyrt.Value {
    mut ranked := []Entry{}
    for key in c.backing.keys {
        score := c.get_item(key)!
        mut insert_at := ranked.len
        for i, existing in ranked {
            if pyrt.gt(score, existing.value)! { insert_at = i; break }
        }
        mut reordered := []Entry{}
        for i, element in ranked {
            if i == insert_at { reordered << Entry{key: key, value: score} }
            reordered << element
        }
        if insert_at == ranked.len { reordered << Entry{key: key, value: score} }
        ranked = reordered.clone()
    }
    mut limit := ranked.len
    if requested := n {
        limit = requested
        if limit < 0 { limit = 0 }
        if limit > ranked.len { limit = ranked.len }
    }
    mut out := []pyrt.Value{}
    for i in 0 .. limit {
        out << pyrt.Value(pyrt.new_tuple([ranked[i].key, ranked[i].value]))
    }
    return out
}

pub fn (c &Counter) total() !pyrt.Value {
    mut sum := pyrt.Value(i64(0))
    for key in c.backing.keys { sum = pyrt.add(sum, c.get_item(key)!)! }
    return sum
}

pub fn (c &Counter) clear() {
    unsafe {
        c.backing.keys = []pyrt.Value{}
        c.backing.values = map[string]pyrt.Value{}
    }
}

pub fn (c &Counter) copy() !&Counter {
    out := counter(pyrt.none_)!
    for key in c.backing.keys { out.set_item(key, c.get_item(key)!)! }
    return out
}

// Binary + and - discard zero/negative counts, matching Counter's operators.
pub fn (c &Counter) add_counter(other &Counter) !&Counter {
    out := counter(pyrt.none_)!
    mut keys := c.backing.keys.clone()
    for key in other.backing.keys {
        hash := pyrt.hash_key(key)!
        if hash !in c.backing.values { keys << key }
    }
    for key in keys {
        val := pyrt.add(c.get_item(key)!, other.get_item(key)!)!
        if pyrt.gt(val, pyrt.Value(i64(0)))! { out.set_item(key, val)! }
    }
    return out
}

pub fn (c &Counter) sub_counter(other &Counter) !&Counter {
    out := counter(pyrt.none_)!
    mut keys := c.backing.keys.clone()
    for key in other.backing.keys {
        hash := pyrt.hash_key(key)!
        if hash !in c.backing.values { keys << key }
    }
    for key in keys {
        val := pyrt.sub(c.get_item(key)!, other.get_item(key)!)!
        if pyrt.gt(val, pyrt.Value(i64(0)))! { out.set_item(key, val)! }
    }
    return out
}

// An OrderedDict uses the core's insertion-ordered dictionary implementation.
// move_to_end and order-sensitive equality are not provided here.
pub fn ordered_dict(entries []Entry) !&pyrt.Dict {
    out := pyrt.new_dict()
    for entry in entries { pyrt.setitem(pyrt.Value(out), entry.key, entry.value)! }
    return out
}

@[params]
pub struct DequeOptions {
pub:
    maxlen ?int
}

pub struct Deque {
mut:
    data []pyrt.Value
    identity i64
pub:
    maxlen ?int
}

pub fn deque(items []pyrt.Value, options DequeOptions) !&Deque {
    if n := options.maxlen {
        if n < 0 { return pyrt.raise('ValueError', 'maxlen must be non-negative') }
    }
    mut d := &Deque{data: []pyrt.Value{}, identity: pyrt.identity_token(),
        maxlen: options.maxlen}
    d.extend(items)
    return d
}

pub fn (d &Deque) as_value() pyrt.Value { return pyrt.Value(pyrt.Sequence(d)) }
pub fn (d &Deque) pyrt_identity() i64 { return d.identity }
pub fn (d &Deque) len() int { return d.data.len }
pub fn (d &Deque) iter() []pyrt.Value { return d.data.clone() }

fn normalized(i int, n int) !int {
    actual := if i < 0 { i + n } else { i }
    if actual < 0 || actual >= n { return pyrt.raise('IndexError', 'deque index out of range') }
    return actual
}

pub fn (d &Deque) get(i int) !pyrt.Value {
    return d.data[normalized(i, d.data.len)!]
}

pub fn (mut d Deque) set(i int, item pyrt.Value) ! {
    d.data[normalized(i, d.data.len)!] = item
}

pub fn (mut d Deque) delete(i int) ! {
    k := normalized(i, d.data.len)!
    mut result := []pyrt.Value{}
    for j, value in d.data { if j != k { result << value } }
    d.data = result.clone()
}

pub fn (mut d Deque) append(item pyrt.Value) {
    if limit := d.maxlen {
        if limit == 0 { return }
        if d.data.len == limit {
            mut replacement := []pyrt.Value{}
            for i in 1 .. d.data.len { replacement << d.data[i] }
            d.data = replacement.clone()
        }
    }
    d.data << item
}

pub fn (mut d Deque) appendleft(item pyrt.Value) {
    if limit := d.maxlen { if limit == 0 { return } }
    mut replacement := [item]
    replacement << d.data
    if limit := d.maxlen {
        if replacement.len > limit { replacement = replacement[0 .. limit].clone() }
    }
    d.data = replacement.clone()
}

pub fn (mut d Deque) extend(items []pyrt.Value) {
    // Clone to preserve CPython's extend(d, d) snapshot behavior.
    snapshot := items.clone()
    for item in snapshot { d.append(item) }
}

pub fn (mut d Deque) extendleft(items []pyrt.Value) {
    snapshot := items.clone()
    for item in snapshot { d.appendleft(item) }
}

pub fn (mut d Deque) pop() !pyrt.Value {
    if d.data.len == 0 { return pyrt.raise('IndexError', 'pop from an empty deque') }
    return d.data.pop()
}

pub fn (mut d Deque) popleft() !pyrt.Value {
    if d.data.len == 0 { return pyrt.raise('IndexError', 'pop from an empty deque') }
    first := d.data[0]
    mut replacement := []pyrt.Value{}
    for i in 1 .. d.data.len { replacement << d.data[i] }
    d.data = replacement.clone()
    return first
}

pub fn (mut d Deque) clear() {
    d.data = []pyrt.Value{}
}

pub fn (mut d Deque) rotate(amount int) {
    n := d.data.len
    if n == 0 { return }
    mut steps := amount % n
    if steps < 0 { steps = steps + n }
    if steps == 0 { return }
    mut replacement := []pyrt.Value{}
    for i in n - steps .. n { replacement << d.data[i] }
    for i in 0 .. n - steps { replacement << d.data[i] }
    d.data = replacement.clone()
}

pub fn (d &Deque) count(item pyrt.Value) int {
    mut result := 0
    for old in d.data { if pyrt.eq(old, item) { result = result + 1 } }
    return result
}

pub fn (d &Deque) copy() !&Deque {
    return deque(d.data.clone(), DequeOptions{maxlen: d.maxlen})!
}
