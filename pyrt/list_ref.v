module pyrt

// ListRef owns the shared array descriptor of a list whose aliases can observe mutation.
// Unshared lists and read-only aliases remain native arrays in generated code.
@[heap]
pub struct ListRef[T] {
pub mut:
	items []T
}

// list_ref transfers a freshly created array into a shared descriptor.
pub fn list_ref[T](items []T) &ListRef[T] {
	return &ListRef[T]{ items: items }
}

// list_concat creates a new outer array and preserves the identity of its element objects.
pub fn list_concat[T](left []T, right []T) []T {
	mut result := left.clone()
	result << right
	return result
}

// list_ref_slice evaluates both bounds before normalizing them against the current length.
// The new outer array retains the identity of its element objects.
pub fn list_ref_slice[T](list &ListRef[T], start int, stop int, has_start bool, has_stop bool) []T {
	length := list.items.len
	mut lower := if has_start { start } else { 0 }
	mut upper := if has_stop { stop } else { length }
	if lower < 0 { lower += length }
	if upper < 0 { upper += length }
	lower = if lower < 0 {
		0
	} else if lower > length {
		length
	} else {
		lower
	}
	upper = if upper < lower {
		lower
	} else if upper > length {
		length
	} else {
		upper
	}
	return list.items[lower..upper].clone()
}

// list_ref_assign_slice evaluates the replacement before the target and replaces its slice.
pub fn list_ref_assign_slice[T](replacement []T, list &ListRef[T], start int, stop int, has_start bool, has_stop bool) {
	length := list.items.len
	mut lower := if has_start { start } else { 0 }
	mut upper := if has_stop { stop } else { length }
	if lower < 0 { lower += length }
	if upper < 0 { upper += length }
	lower = if lower < 0 {
		0
	} else if lower > length {
		length
	} else {
		lower
	}
	upper = if upper < lower {
		lower
	} else if upper > length {
		length
	} else {
		upper
	}
	mut result := list.items[..lower].clone()
	result << replacement
	result << list.items[upper..]
	unsafe { list.items = result }
}

// list_ref_indices normalizes Python slice bounds, including a negative step.
fn list_ref_indices(length int, start int, stop int, step int, has_start bool, has_stop bool) []int {
	if step == 0 { panic('slice step cannot be zero') }
	mut slice_start := if has_start {
		start
	} else if step > 0 {
		0
	} else {
		length - 1
	}
	mut slice_stop := if has_stop {
		stop
	} else if step > 0 {
		length
	} else {
		-1
	}
	if has_start {
		if slice_start < 0 { slice_start += length }
	}
	if has_stop {
		if slice_stop < 0 { slice_stop += length }
	}
	if step > 0 {
		slice_start = if slice_start < 0 {
			0
		} else if slice_start > length {
			length
		} else {
			slice_start
		}
		slice_stop = if slice_stop < 0 {
			0
		} else if slice_stop > length {
			length
		} else {
			slice_stop
		}
	} else {
		slice_start = if slice_start < -1 {
			-1
		} else if slice_start >= length {
			length - 1
		} else {
			slice_start
		}
		slice_stop = if slice_stop < -1 {
			-1
		} else if slice_stop >= length {
			length - 1
		} else {
			slice_stop
		}
	}
	mut indices := []int{}
	if step > 0 {
		for i := slice_start; i < slice_stop; i += step { indices << i }
	} else {
		for i := slice_start; i > slice_stop; i += step { indices << i }
	}
	return indices
}

// list_ref_slice_step copies a stepped slice without sharing its outer descriptor.
pub fn list_ref_slice_step[T](list &ListRef[T], start int, stop int, step int, has_start bool, has_stop bool) []T {
	indices := list_ref_indices(list.items.len, start, stop, step, has_start, has_stop)
	mut result := []T{cap: indices.len}
	for index in indices { result << list.items[index] }
	return result
}

// list_ref_delete_slice removes an interval through the shared descriptor.
pub fn list_ref_delete_slice[T](list &ListRef[T], start int, stop int, has_start bool, has_stop bool) {
	list_ref_delete_slice_step(list, start, stop, 1, has_start, has_stop)
}

// list_ref_delete_slice_step removes selected indices through the shared descriptor.
pub fn list_ref_delete_slice_step[T](list &ListRef[T], start int, stop int, step int, has_start bool, has_stop bool) {
	length := list.items.len
	indices := list_ref_indices(length, start, stop, step, has_start, has_stop)
	mut removed := []bool{len: length}
	for index in indices { removed[index] = true }
	mut result := []T{cap: length - indices.len}
	for index, element in list.items {
		if !removed[index] { result << element }
	}
	unsafe { list.items = result }
}

// list_ref_assign_slice_step assigns elements into a stepped selection in place.
pub fn list_ref_assign_slice_step[T](replacement []T, list &ListRef[T], start int, stop int, step int, has_start bool, has_stop bool) {
	indices := list_ref_indices(list.items.len, start, stop, step, has_start, has_stop)
	if indices.len != replacement.len {
		panic('attempt to assign sequence of size ${replacement.len} to extended slice of size ${indices.len}')
	}
	for i, index in indices { list.items[index] = replacement[i] }
}

// len returns the current shared descriptor's length.
pub fn (list &ListRef[T]) len() int {
	return list.items.len
}

// get boxes an element without copying any nested shared list descriptor.
pub fn (list &ListRef[T]) get(index int) !Value {
	at := checked_index(i64(index), list.items.len, 'list index out of range')!
	return box(list.items[at])
}

// set updates an element through a runtime alias, retaining the native element type.
pub fn (mut list ListRef[T]) set(index int, value Value) ! {
	at := checked_index(i64(index), list.items.len, 'list assignment index out of range')!
	list.items[at] = list_ref_element[T](value)!
}

// delete changes the shared descriptor, so every holder observes the new length.
pub fn (mut list ListRef[T]) delete(index int) ! {
	at := checked_index(i64(index), list.items.len, 'list assignment index out of range')!
	list.items.delete(at)
}

// pyrt_identity is stable across descriptor resizing, boxing, and aliasing.
pub fn (list &ListRef[T]) pyrt_identity() i64 {
	return i64(voidptr(list))
}

// ListMethods is the optional resizing protocol used by translated runtime calls.
// It is checked on a standalone Sequence, outside the Value sum-type smartcast.
pub interface ListMethods {
	list_method(name string, args []Value) !Value
}

// list_method applies a runtime method and writes its result to the shared typed descriptor.
pub fn (list &ListRef[T]) list_method(name string, args []Value) !Value {
	mut values := []Value{cap: list.items.len}
	for item in list.items { values << box(item) }
	runtime_list := new_list(values)
	result := list_method(runtime_list, name, args)!
	if name in ['append', 'extend', 'insert', 'pop', 'remove', 'clear', 'reverse', 'sort'] {
		mut replacement := []T{cap: runtime_list.items.len}
		for item in runtime_list.items { replacement << list_ref_element[T](item)! }
		unsafe { list.items = replacement }
	}
	return result
}

fn list_ref_element[T](value Value) !T {
	$if T is Value {
		return value
	} $else $if T is int {
		if value is int { return value }
		if value is i64 {
			if value >= -2147483648 && value <= 2147483647 { return int(value) }
			return raise('OverflowError', 'py2v: runtime integer does not fit shared native int list')
		}
	} $else $if T is i64 {
		if value is int { return i64(value) }
		if value is i64 { return value }
	} $else $if T is f64 {
		if value is f64 { return value }
	} $else $if T is string {
		if value is string { return value }
	} $else $if T is bool {
		if value is bool { return value }
	} $else $if T is Sequence {
		if value is Sequence { return list_ref_sequence(value, T{}) }
	}
	return raise('TypeError', 'py2v: shared native list cannot hold runtime ${type_name(value)}')
}

// list_ref_sequence checks the concrete descriptor, not a generic pointer type in `is`.
// V 0.5.2 cannot instantiate that pointer type test for nested ListRef elements.
fn list_ref_sequence[T](sequence Sequence, hint &ListRef[T]) !&ListRef[T] {
	if sequence is ListBridge { return list_ref_sequence[T](sequence.sequence, hint) }
	if sequence is ListRef[T] { return unsafe { &sequence } }
	return raise('TypeError', 'py2v: incompatible shared native list element')
}

fn sequence_invoke(sequence Sequence, name string, args []Value) !Value {
	if sequence is ListBridge {
		return sequence.methods.list_method(name, args)!
	}
	// A generic Sequence supports indexed operations and snapshots, but not resizing.
	if name == 'copy' {
		return Value(new_list(iter(Value(sequence))!))
	}
	if name == 'count' {
		arity(name, 'list', args, 1, 1)!
		mut n := i64(0)
		for item in iter(Value(sequence))! {
			if eq(item, args[0]) {
				n = n + 1
			}
		}
		return Value(n)
	}
	return raise('NotImplementedError', 'typed Sequence does not support list method ${name}')
}

// ListBridge records both protocols while the concrete generic list type is available.
// This avoids an interface-to-interface cast in the pinned V compiler.
@[heap]
pub struct ListBridge {
	methods ListMethods
mut:
	sequence Sequence
}

// len reads the current length through the original shared descriptor.
pub fn (bridge &ListBridge) len() int { return bridge.sequence.len() }

// get reads an element through the original shared descriptor.
pub fn (bridge &ListBridge) get(index int) !Value { return bridge.sequence.get(index)! }

// set updates an element through the original shared descriptor.
pub fn (mut bridge ListBridge) set(index int, value Value) ! { bridge.sequence.set(index, value)! }

// delete removes an element through the original shared descriptor.
pub fn (mut bridge ListBridge) delete(index int) ! { bridge.sequence.delete(index)! }

// pyrt_identity identifies the list, independently of how often it has been boxed.
pub fn (bridge &ListBridge) pyrt_identity() i64 { return bridge.sequence.pyrt_identity() }
